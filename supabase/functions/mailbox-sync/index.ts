import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// "Email Palestra": ogni 15 minuti (pg_cron) questa funzione si collega via
// IMAP alla casella condivisa della palestra su Aruba, salva un riepilogo di
// ogni email nuova in mailbox_messages e, se ha un allegato PDF, lo fa
// leggere a Claude per estrarre importo/scadenza/descrizione e crea una riga
// in mailbox_invoices. Gira interamente con la service role (le tabelle
// mailbox_* sono altrimenti chiuse in scrittura per chiunque altro).
//
// Approccio IMAP: non esiste nell'ecosistema Deno una libreria IMAP matura e
// affidabile paragonabile a "denomailer" per SMTP (a differenza di
// admin-ask-claude che infatti riusa un client Postgres via TCP, qui non
// c'è un pacchetto equivalente da citare con fiducia). Per non rischiare di
// affidarmi a un pacchetto npm non pensato per un runtime Deno sandboxato,
// ho implementato IL MINIMO INDISPENSABILE del protocollo IMAP4rev1 (RFC
// 3501) sopra Deno.connectTls: LOGIN (con literal, per gestire qualunque
// carattere nella password senza escaping), SELECT, UID SEARCH, UID FETCH di
// ENVELOPE/BODYSTRUCTURE e del singolo part di testo/allegato che serve.
// Copre esattamente i casi che servono qui (email semplici o multipart con
// un allegato), non l'intero standard MIME.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// ============================================================================
// Client IMAP minimale
// ============================================================================

const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** Trova l'indice di un CRLF in un buffer di byte, o -1. */
function indexOfCrlf(buf: Uint8Array): number {
  for (let i = 0; i < buf.length - 1; i++) {
    if (buf[i] === 13 && buf[i + 1] === 10) return i;
  }
  return -1;
}

/** Placeholder che non può comparire in una risposta IMAP testuale vera. */
const LITERAL_MARK = "\u0000";

class ImapClient {
  #conn: Deno.TlsConn | null = null;
  #buf = new Uint8Array(0);
  #tagCounter = 0;

  async connect(hostname: string, port: number): Promise<void> {
    this.#conn = await Deno.connectTls({ hostname, port });
    // Il server manda subito una riga di saluto "* OK ...".
    await this.#readLogicalLine();
  }

  close(): void {
    try {
      this.#conn?.close();
    } catch (_e) {
      // Già chiusa — non importa.
    }
  }

  #nextTag(): string {
    this.#tagCounter++;
    return `A${this.#tagCounter}`;
  }

  async #fill(): Promise<boolean> {
    if (!this.#conn) throw new Error("Connessione IMAP non attiva.");
    const chunk = new Uint8Array(8192);
    const n = await this.#conn.read(chunk);
    if (n === null) return false;
    const merged = new Uint8Array(this.#buf.length + n);
    merged.set(this.#buf);
    merged.set(chunk.subarray(0, n), this.#buf.length);
    this.#buf = merged;
    return true;
  }

  async #readExact(n: number): Promise<string> {
    while (this.#buf.length < n) {
      const more = await this.#fill();
      if (!more) throw new Error("Connessione IMAP chiusa inaspettatamente.");
    }
    const data = this.#buf.subarray(0, n);
    this.#buf = this.#buf.subarray(n);
    return decoder.decode(data);
  }

  async #readRawLine(): Promise<string> {
    while (true) {
      const idx = indexOfCrlf(this.#buf);
      if (idx !== -1) {
        const line = decoder.decode(this.#buf.subarray(0, idx));
        this.#buf = this.#buf.subarray(idx + 2);
        return line;
      }
      const more = await this.#fill();
      if (!more) throw new Error("Connessione IMAP chiusa inaspettatamente.");
    }
  }

  /**
   * Legge una "riga logica" di risposta IMAP, risolvendo eventuali literal
   * `{n}` incontrati lungo la riga (il contenuto del literal viene letto per
   * byte esatti, ignorando eventuali CRLF al suo interno, poi la lettura
   * della riga prosegue). Ogni literal risolto viene sostituito nel testo
   * con un marcatore univoco `\u0000<indice>\u0000`, così il parser più
   * sotto lo riconosce come un unico atomo senza doverne re-interpretare il
   * contenuto (che potrebbe contenere parentesi, spazi, virgolette...).
   */
  async #readLogicalLine(): Promise<{ text: string; literals: string[] }> {
    const literals: string[] = [];
    let text = "";
    while (true) {
      const line = await this.#readRawLine();
      const m = line.match(/\{(\d+)\}$/);
      if (!m) {
        text += line;
        return { text, literals };
      }
      text += line.slice(0, m.index);
      const literalLength = parseInt(m[1], 10);
      const literalContent = await this.#readExact(literalLength);
      const idx = literals.length;
      literals.push(literalContent);
      text += `${LITERAL_MARK}${idx}${LITERAL_MARK}`;
      // La riga continua dopo il literal (es. altri campi o la parentesi di
      // chiusura) — il ciclo legge la prossima riga raw e la concatena.
    }
  }

  async #writeLine(line: string): Promise<void> {
    if (!this.#conn) throw new Error("Connessione IMAP non attiva.");
    await this.#conn.write(encoder.encode(`${line}\r\n`));
  }

  async #writeRaw(text: string): Promise<void> {
    if (!this.#conn) throw new Error("Connessione IMAP non attiva.");
    await this.#conn.write(encoder.encode(text));
  }

  /** Attende una risposta di continuazione "+ ...". */
  async #expectContinuation(): Promise<void> {
    const { text } = await this.#readLogicalLine();
    if (!text.startsWith("+")) {
      throw new Error(`Continuazione IMAP attesa, ricevuto: ${text}`);
    }
  }

  async login(user: string, password: string): Promise<void> {
    const tag = this.#nextTag();
    const userBytes = encoder.encode(user);
    const passBytes = encoder.encode(password);

    await this.#writeLine(`${tag} LOGIN {${userBytes.length}}`);
    await this.#expectContinuation();
    await this.#writeRaw(user);
    await this.#writeLine(` {${passBytes.length}}`);
    await this.#expectContinuation();
    await this.#writeRaw(password);
    await this.#writeLine("");

    await this.#readUntilTagged(tag, "LOGIN");
  }

  async selectInbox(): Promise<void> {
    const tag = this.#nextTag();
    await this.#writeLine(`${tag} SELECT INBOX`);
    await this.#readUntilTagged(tag, "SELECT");
  }

  async logout(): Promise<void> {
    const tag = this.#nextTag();
    try {
      await this.#writeLine(`${tag} LOGOUT`);
      await this.#readUntilTagged(tag, "LOGOUT");
    } catch (_e) {
      // Stiamo comunque per chiudere la connessione — non critico.
    }
  }

  /** Legge righe finché non arriva la risposta taggata (OK/NO/BAD). */
  async #readUntilTagged(
    tag: string,
    label: string,
  ): Promise<{ text: string; literals: string[] }[]> {
    const lines: { text: string; literals: string[] }[] = [];
    while (true) {
      const resolved = await this.#readLogicalLine();
      if (resolved.text.startsWith(`${tag} `)) {
        if (!/\bOK\b/i.test(resolved.text)) {
          throw new Error(`${label} fallita: ${resolved.text}`);
        }
        return lines;
      }
      lines.push(resolved);
    }
  }

  async uidSearch(searchKey: string): Promise<number[]> {
    const tag = this.#nextTag();
    await this.#writeLine(`${tag} UID SEARCH ${searchKey}`);
    const lines = await this.#readUntilTagged(tag, "UID SEARCH");
    const uids: number[] = [];
    for (const { text } of lines) {
      if (text.startsWith("* SEARCH")) {
        const rest = text.slice("* SEARCH".length).trim();
        if (rest) {
          for (const token of rest.split(/\s+/)) {
            const n = parseInt(token, 10);
            if (!isNaN(n)) uids.push(n);
          }
        }
      }
    }
    return uids;
  }

  /** ENVELOPE + BODYSTRUCTURE + stato letto/non letto (\Seen) per un UID. */
  async fetchEnvelopeAndStructure(
    uid: number,
  ): Promise<{ envelope: ImapValue; bodystructure: ImapValue; isUnread: boolean } | null> {
    const tag = this.#nextTag();
    await this.#writeLine(`${tag} UID FETCH ${uid} (FLAGS ENVELOPE BODYSTRUCTURE)`);
    const lines = await this.#readUntilTagged(tag, "UID FETCH");
    const fetchLine = lines.find(
      (l) => l.text.startsWith("* ") && /\bFETCH\b/.test(l.text),
    );
    if (!fetchLine) return null;

    const parser = new ImapListParser(fetchLine.text, fetchLine.literals);
    // Salta fino alla parentesi che apre la lista di attributi del FETCH.
    parser.skipUntilChar("(");
    const attrs = parser.parseParenListRaw();
    const envelope = extractNamedValue(attrs, "ENVELOPE");
    const bodystructure = extractNamedValue(attrs, "BODYSTRUCTURE");
    const isUnread = !hasSeenFlag(extractNamedValue(attrs, "FLAGS"));
    return { envelope, bodystructure, isUnread };
  }

  /**
   * FLAGS di più UID in un solo giro di FETCH (non uno per uno): usato per
   * ricontrollare lo stato letto/non letto reale di email già salvate,
   * senza dover riaprire una connessione o un FETCH per ciascuna. Ritorna
   * una mappa uid -> isUnread; un UID richiesto ma non più presente nella
   * casella (es. cancellato) semplicemente non compare nella mappa.
   */
  async fetchFlags(uids: number[]): Promise<Map<number, boolean>> {
    const result = new Map<number, boolean>();
    if (uids.length === 0) return result;

    const tag = this.#nextTag();
    await this.#writeLine(`${tag} UID FETCH ${uids.join(",")} (FLAGS)`);
    const lines = await this.#readUntilTagged(tag, "UID FETCH");
    for (const { text } of lines) {
      if (!text.startsWith("* ") || !/\bFETCH\b/.test(text)) continue;
      // Con UID FETCH il server include sempre l'UID nella risposta (RFC
      // 3501), anche se non richiesto esplicitamente tra gli attributi.
      const uidMatch = text.match(/\bUID (\d+)\b/);
      if (!uidMatch) continue;
      const uid = parseInt(uidMatch[1], 10);
      result.set(uid, !/\\Seen\b/i.test(text));
    }
    return result;
  }

  /** Contenuto grezzo (già risolto dai literal) di un singolo body part. */
  async fetchBodyPart(
    uid: number,
    partNumber: string,
    maxBytes?: number,
  ): Promise<string> {
    const tag = this.#nextTag();
    const range = maxBytes ? `<0.${maxBytes}>` : "";
    await this.#writeLine(
      `${tag} UID FETCH ${uid} (BODY.PEEK[${partNumber}]${range})`,
    );
    const lines = await this.#readUntilTagged(tag, "UID FETCH");
    const fetchLine = lines.find(
      (l) => l.text.startsWith("* ") && /\bFETCH\b/.test(l.text),
    );
    if (!fetchLine) return "";
    // Il contenuto del part è l'unico literal presente nella risposta.
    return fetchLine.literals[0] ?? "";
  }
}

// ============================================================================
// Parser minimale per le liste IMAP tra parentesi (ENVELOPE, BODYSTRUCTURE)
// ============================================================================

type ImapValue = string | null | ImapValue[];

class ImapListParser {
  #text: string;
  #literals: string[];
  #pos = 0;

  constructor(text: string, literals: string[]) {
    this.#text = text;
    this.#literals = literals;
  }

  skipUntilChar(ch: string): void {
    const idx = this.#text.indexOf(ch, this.#pos);
    if (idx === -1) throw new Error(`Carattere '${ch}' non trovato nella risposta IMAP.`);
    this.#pos = idx;
  }

  #skipSpaces(): void {
    while (this.#pos < this.#text.length && this.#text[this.#pos] === " ") {
      this.#pos++;
    }
  }

  /** Assume che this.#pos punti a '(' e ritorna la lista appena letta. */
  parseParenListRaw(): ImapValue[] {
    if (this.#text[this.#pos] !== "(") {
      throw new Error("Attesa una lista tra parentesi.");
    }
    this.#pos++; // consuma '('
    const items: ImapValue[] = [];
    while (true) {
      this.#skipSpaces();
      if (this.#pos >= this.#text.length) {
        throw new Error("Lista IMAP non chiusa correttamente.");
      }
      if (this.#text[this.#pos] === ")") {
        this.#pos++;
        return items;
      }
      items.push(this.#parseValue());
    }
  }

  #parseValue(): ImapValue {
    this.#skipSpaces();
    const c = this.#text[this.#pos];
    if (c === "(") {
      return this.parseParenListRaw();
    }
    if (c === LITERAL_MARK) {
      // Marcatore \u0000<indice>\u0000 di un literal già risolto.
      const end = this.#text.indexOf(LITERAL_MARK, this.#pos + 1);
      const idx = parseInt(this.#text.slice(this.#pos + 1, end), 10);
      this.#pos = end + 1;
      return this.#literals[idx] ?? "";
    }
    if (c === '"') {
      let end = this.#pos + 1;
      let out = "";
      while (this.#text[end] !== '"') {
        if (this.#text[end] === "\\") {
          out += this.#text[end + 1];
          end += 2;
        } else {
          out += this.#text[end];
          end += 1;
        }
      }
      this.#pos = end + 1;
      return out;
    }
    // Atomo non quotato: NIL, un numero, una flag, ecc. Termina a spazio o
    // parentesi.
    let end = this.#pos;
    while (
      end < this.#text.length &&
      this.#text[end] !== " " &&
      this.#text[end] !== "(" &&
      this.#text[end] !== ")"
    ) {
      end++;
    }
    const atom = this.#text.slice(this.#pos, end);
    this.#pos = end;
    return atom.toUpperCase() === "NIL" ? null : atom;
  }
}

/** Cerca "NOME (...)" dentro una lista già estratta (es. attributi FETCH). */
function extractNamedValue(list: ImapValue[], name: string): ImapValue {
  for (let i = 0; i < list.length - 1; i++) {
    if (typeof list[i] === "string" && (list[i] as string).toUpperCase() === name) {
      return list[i + 1];
    }
  }
  return null;
}

/** True se la lista FLAGS (già estratta) contiene \Seen. */
function hasSeenFlag(flags: ImapValue): boolean {
  return Array.isArray(flags) &&
    flags.some((f) => typeof f === "string" && f.toUpperCase() === "\\SEEN");
}

// ============================================================================
// Lettura di ENVELOPE / BODYSTRUCTURE già parsati in ImapValue
// ============================================================================

interface ParsedEnvelope {
  date: string | null;
  subject: string | null;
  fromAddress: string | null;
  messageIdHeader: string | null;
}

/** Decodifica minimale delle "encoded words" RFC 2047 (=?charset?B/Q?...?=). */
function decodeEncodedWords(input: string): string {
  return input.replace(
    /=\?([^?]+)\?([bBqQ])\?([^?]*)\?=/g,
    (_match, _charset, enc, data) => {
      try {
        if (enc.toUpperCase() === "B") {
          return decoder.decode(
            Uint8Array.from(atob(data), (c) => c.charCodeAt(0)),
          );
        }
        // Quoted-printable "Q": '_' vale spazio, poi le sequenze =XX.
        const withSpaces = data.replace(/_/g, " ");
        return decoder.decode(decodeQuotedPrintableToBytes(withSpaces));
      } catch (_e) {
        return data;
      }
    },
  );
}

function parseEnvelope(envelope: ImapValue): ParsedEnvelope {
  if (!Array.isArray(envelope)) {
    return { date: null, subject: null, fromAddress: null, messageIdHeader: null };
  }
  const [date, subject, from, , , , , , , messageId] = envelope as ImapValue[];

  let fromAddress: string | null = null;
  if (Array.isArray(from) && Array.isArray(from[0])) {
    const addr = from[0] as ImapValue[];
    const [name, , mailbox, host] = addr;
    const email = mailbox && host ? `${mailbox}@${host}` : null;
    const displayName = typeof name === "string" ? decodeEncodedWords(name) : null;
    fromAddress = displayName && email ? `${displayName} <${email}>` : email;
  }

  return {
    date: typeof date === "string" ? date : null,
    subject: typeof subject === "string" ? decodeEncodedWords(subject) : null,
    fromAddress,
    messageIdHeader: typeof messageId === "string" ? messageId : null,
  };
}

interface BodyPart {
  partNumber: string;
  type: string;
  subtype: string;
  encoding: string;
  filename: string | null;
}

/** Cerca un parametro (NAME/FILENAME) in una lista di parametri IMAP. */
function findParam(params: ImapValue, key: string): string | null {
  if (!Array.isArray(params)) return null;
  for (let i = 0; i < params.length - 1; i += 2) {
    if (typeof params[i] === "string" && (params[i] as string).toUpperCase() === key) {
      return typeof params[i + 1] === "string" ? (params[i + 1] as string) : null;
    }
  }
  return null;
}

/** Appiattisce ricorsivamente una BODYSTRUCTURE nei suoi leaf part. */
function walkBodyStructure(node: ImapValue, prefix: string, out: BodyPart[]): void {
  if (!Array.isArray(node)) return;

  const isMultipart = Array.isArray(node[0]);
  if (isMultipart) {
    let index = 1;
    for (const child of node) {
      if (!Array.isArray(child)) break; // fine sotto-parti, resto è subtype/extension
      const partNumber = prefix ? `${prefix}.${index}` : `${index}`;
      walkBodyStructure(child, partNumber, out);
      index++;
    }
    return;
  }

  const type = typeof node[0] === "string" ? (node[0] as string).toUpperCase() : "";
  const subtype = typeof node[1] === "string" ? (node[1] as string).toUpperCase() : "";
  const params = node[2];
  const encoding = typeof node[5] === "string" ? (node[5] as string).toUpperCase() : "7BIT";

  // Il filename può stare nei parametri di Content-Type (NAME) o
  // nell'eventuale extension data di Content-Disposition (non sempre
  // presente/nella stessa posizione a seconda del server) — controlliamo
  // solo NAME, che è il caso comune per gli allegati inviati da sistemi di
  // fatturazione.
  const filename = findParam(params, "NAME");

  out.push({
    partNumber: prefix || "1",
    type,
    subtype,
    encoding,
    filename,
  });
}

/**
 * Decodifica quoted-printable ai byte grezzi (non a una stringa JS diretta):
 * il contenuto originale può essere UTF-8 multi-byte (es. lettere accentate
 * italiane), quindi bisogna prima ricostruire i byte e poi decodificarli
 * tutti insieme con TextDecoder, invece di trattare ogni singolo byte come
 * un carattere a sé (che romperebbe i caratteri multi-byte).
 */
function decodeQuotedPrintableToBytes(input: string): Uint8Array {
  const withoutSoftBreaks = input.replace(/=\r?\n/g, "");
  const bytes: number[] = [];
  for (let i = 0; i < withoutSoftBreaks.length; i++) {
    const ch = withoutSoftBreaks[i];
    const hex = withoutSoftBreaks.slice(i + 1, i + 3);
    if (ch === "=" && /^[0-9A-Fa-f]{2}$/.test(hex)) {
      bytes.push(parseInt(hex, 16));
      i += 2;
    } else {
      bytes.push(ch.charCodeAt(0));
    }
  }
  return new Uint8Array(bytes);
}

/**
 * Decodifica il contenuto grezzo (già estratto dal literal IMAP) di un body
 * part secondo il suo Content-Transfer-Encoding. Assume che un part BASE64
 * non testuale (es. un PDF) sia sempre codificato in base64 dal mittente —
 * vero in pratica per qualunque allegato binario inviato via email — quindi
 * non gestisce il caso (di fatto inesistente) di un PDF trasmesso 7BIT/8BIT
 * grezzo, che verrebbe corrotto passando dal TextDecoder UTF-8 qui sotto.
 */
function decodeBodyPart(raw: string, encoding: string): string {
  switch (encoding) {
    case "BASE64":
      try {
        return decoder.decode(
          Uint8Array.from(atob(raw.replace(/\s+/g, "")), (c) => c.charCodeAt(0)),
        );
      } catch (_e) {
        return "";
      }
    case "QUOTED-PRINTABLE":
      return decoder.decode(decodeQuotedPrintableToBytes(raw));
    default:
      return raw;
  }
}

function htmlToPlainText(html: string): string {
  return html
    .replace(/<(script|style)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'");
}

function buildSnippet(text: string): string {
  const collapsed = text.replace(/\s+/g, " ").trim();
  return collapsed.length > 300 ? `${collapsed.slice(0, 300)}…` : collapsed;
}

// ============================================================================
// Lettura della fattura allegata con Claude
// ============================================================================

interface InvoiceExtraction {
  amount: number | null;
  due_date: string | null;
  description: string | null;
  /**
   * True se il documento è davvero una fattura/bolletta/avviso di pagamento
   * con un importo dovuto (quindi va creata una riga in mailbox_invoices).
   * Di default true quando Claude non è stato consultato o non ha risposto
   * in modo utilizzabile: meglio una fattura vera creata per errore in più
   * (l'admin la ignora) che perderne una a causa di un errore tecnico.
   */
  is_invoice: boolean;
}

function extractJsonObject(text: string): Record<string, unknown> {
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```[a-zA-Z]*\n?/, "").replace(/```\s*$/, "");
  }
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) {
    throw new Error("La risposta del modello non contiene un oggetto JSON.");
  }
  return JSON.parse(cleaned.slice(start, end + 1));
}

const INVOICE_PROMPT = `Questo è un PDF allegato a un'email ricevuta dalla palestra. Potrebbe essere una fattura/bolletta/avviso di pagamento, oppure materiale commerciale, informativo, una guida o una newsletter che non richiede alcun pagamento. Leggilo ed estrai SOLO i dati richiesti.

Rispondi SOLO con un oggetto JSON valido (nessun testo prima o dopo, nessun blocco markdown), con questi campi esatti:
- "is_invoice": true SOLO se il documento è davvero una fattura, una bolletta o un avviso di pagamento con un importo dovuto e (di solito) una scadenza; false se è materiale commerciale, informativo, una guida, una newsletter o qualunque altro PDF che non richiede un pagamento
- "amount": l'importo totale da pagare, come numero (es. 123.45), o null se non riesci a leggerlo con sufficiente certezza
- "due_date": la data di scadenza del pagamento in formato YYYY-MM-DD, o null se non è indicata o non è leggibile con certezza
- "description": una breve descrizione di cosa riguarda (es. "Bolletta luce - Enel", "Fattura commercialista"), max 100 caratteri, o null se non riesci a determinarla

Se un valore non è leggibile con sufficiente certezza, usa null per quel campo invece di indovinare.`;

async function readInvoiceWithClaude(
  pdfBase64: string,
  apiKey: string,
  model: string,
): Promise<InvoiceExtraction> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "document",
              source: {
                type: "base64",
                media_type: "application/pdf",
                data: pdfBase64,
              },
            },
            { type: "text", text: INVOICE_PROMPT },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    console.error("mailbox-sync: Anthropic API error:", await response.text());
    return { amount: null, due_date: null, description: null, is_invoice: true };
  }

  const data = await response.json();
  const textBlock = (data.content ?? []).find(
    (block: { type: string }) => block.type === "text",
  );
  if (!textBlock?.text) {
    return { amount: null, due_date: null, description: null, is_invoice: true };
  }

  try {
    const parsed = extractJsonObject(textBlock.text);
    const amount = typeof parsed.amount === "number" ? parsed.amount : null;
    const dueDate =
      typeof parsed.due_date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(parsed.due_date)
        ? parsed.due_date
        : null;
    const description =
      typeof parsed.description === "string" ? parsed.description.slice(0, 100) : null;
    // Se Claude non ha risposto con un booleano chiaro, meglio assumere che
    // sia una fattura vera (is_invoice: true) piuttosto che rischiare di
    // scartarne una per una risposta malformata.
    const isInvoice =
      typeof parsed.is_invoice === "boolean" ? parsed.is_invoice : true;
    return { amount, due_date: dueDate, description, is_invoice: isInvoice };
  } catch (error) {
    console.error("mailbox-sync: could not parse Claude invoice response:", error);
    return { amount: null, due_date: null, description: null, is_invoice: true };
  }
}

function base64FromBinaryString(binary: string): string {
  return btoa(binary);
}

/**
 * Ricontrolla lo stato letto/non letto reale (via IMAP) delle email già
 * salvate ma "potenzialmente ancora aperte di recente altrove" (webmail,
 * altro client): quelle segnate is_unread=true, più tutte quelle arrivate
 * negli ultimi 14 giorni (per non dover ricontrollare l'intero storico a
 * ogni giro). Un solo giro di FETCH per tutti gli UID insieme, non uno per
 * uno. Ritorna quante righe sono state effettivamente aggiornate.
 */
async function recheckReadStatus(
  imap: ImapClient,
  adminClient: ReturnType<typeof createClient>,
): Promise<number> {
  const fourteenDaysAgo = new Date();
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

  const { data: candidates, error } = await adminClient
    .from("mailbox_messages")
    .select("id, message_uid, is_unread")
    .or(`is_unread.eq.true,received_at.gte.${fourteenDaysAgo.toISOString()}`);

  if (error) {
    console.error("mailbox-sync: ricontrollo letto/non letto, lettura righe fallita:", error);
    return 0;
  }
  if (!candidates || candidates.length === 0) return 0;

  const uidToRow = new Map<number, { id: string; isUnread: boolean }>();
  for (const row of candidates as Array<
    { id: string; message_uid: string | null; is_unread: boolean }
  >) {
    const uidNum = row.message_uid ? parseInt(row.message_uid, 10) : NaN;
    if (!isNaN(uidNum)) {
      uidToRow.set(uidNum, { id: row.id, isUnread: row.is_unread });
    }
  }
  if (uidToRow.size === 0) return 0;

  const flagsByUid = await imap.fetchFlags([...uidToRow.keys()]);

  let updated = 0;
  for (const [uid, row] of uidToRow) {
    const realIsUnread = flagsByUid.get(uid);
    // Un UID richiesto ma non tornato nella risposta (es. il messaggio è
    // stato cancellato dalla casella) non va toccato.
    if (realIsUnread === undefined || realIsUnread === row.isUnread) continue;

    const { error: updateError } = await adminClient
      .from("mailbox_messages")
      .update({ is_unread: realIsUnread })
      .eq("id", row.id);
    if (updateError) {
      console.error(
        `mailbox-sync: impossibile aggiornare is_unread per il messaggio ${row.id}:`,
        updateError,
      );
    } else {
      updated++;
    }
  }
  return updated;
}

// ============================================================================
// Gestore principale
// ============================================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const ARUBA_EMAIL = Deno.env.get("ARUBA_EMAIL");
  const ARUBA_EMAIL_PASSWORD = Deno.env.get("ARUBA_EMAIL_PASSWORD");
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
  const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") || "claude-sonnet-5";

  if (!ARUBA_EMAIL || !ARUBA_EMAIL_PASSWORD || !SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("mailbox-sync: variabili d'ambiente mancanti.");
    return jsonResponse({ error: "Configurazione mancante." }, 500);
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: stateRow } = await adminClient
    .from("mailbox_sync_state")
    .select("last_uid")
    .eq("id", 1)
    .maybeSingle();
  const lastUid: number | null = stateRow?.last_uid ?? null;

  let processed = 0;
  let newLastUid = lastUid;
  const imap = new ImapClient();

  try {
    await imap.connect("imaps.aruba.it", 993);
    await imap.login(ARUBA_EMAIL, ARUBA_EMAIL_PASSWORD);
    await imap.selectInbox();

    const searchKey = lastUid !== null ? `UID ${lastUid + 1}:*` : "ALL";
    let uids = await imap.uidSearch(searchKey);
    if (lastUid === null) {
      // Primo sync: evita di processare tutto lo storico della casella,
      // prendi solo le email più recenti.
      uids = uids.slice(-20);
    }

    for (const uid of uids) {
      try {
        const fetched = await imap.fetchEnvelopeAndStructure(uid);
        if (!fetched) continue;
        const envelope = parseEnvelope(fetched.envelope);

        const parts: BodyPart[] = [];
        walkBodyStructure(fetched.bodystructure, "", parts);
        const isMultipart = Array.isArray(fetched.bodystructure) &&
          Array.isArray((fetched.bodystructure as ImapValue[])[0]);

        const textPart = parts.find((p) => p.type === "TEXT" && p.subtype === "PLAIN") ??
          parts.find((p) => p.type === "TEXT");
        const pdfPart = parts.find(
          (p) =>
            (p.type === "APPLICATION" && p.subtype === "PDF") ||
            (p.filename ?? "").toLowerCase().endsWith(".pdf"),
        );
        const hasAttachment = isMultipart &&
          parts.some((p) => p.filename !== null || p.type === "APPLICATION");

        let snippet = "";
        if (textPart) {
          try {
            const raw = await imap.fetchBodyPart(uid, textPart.partNumber, 2000);
            let decoded = decodeBodyPart(raw, textPart.encoding);
            if (textPart.subtype === "HTML") decoded = htmlToPlainText(decoded);
            snippet = buildSnippet(decoded);
          } catch (error) {
            console.error(`mailbox-sync: snippet non leggibile per UID ${uid}:`, error);
          }
        }

        const receivedAt = envelope.date ? new Date(envelope.date) : null;
        const { data: insertedMessage, error: insertError } = await adminClient
          .from("mailbox_messages")
          .insert({
            message_uid: String(uid),
            message_id_header: envelope.messageIdHeader,
            from_address: envelope.fromAddress,
            subject: envelope.subject,
            received_at: receivedAt && !isNaN(receivedAt.getTime())
              ? receivedAt.toISOString()
              : null,
            snippet,
            has_attachment: hasAttachment,
            is_unread: fetched.isUnread,
          })
          .select("id")
          .single();

        if (insertError || !insertedMessage) {
          console.error(`mailbox-sync: impossibile salvare il messaggio UID ${uid}:`, insertError);
          continue;
        }

        if (pdfPart) {
          try {
            const rawPdf = await imap.fetchBodyPart(uid, pdfPart.partNumber);
            const pdfBase64 = pdfPart.encoding === "BASE64"
              ? rawPdf.replace(/\s+/g, "")
              : base64FromBinaryString(decodeBodyPart(rawPdf, pdfPart.encoding));

            const fileName = pdfPart.filename && pdfPart.filename.trim()
              ? pdfPart.filename.trim().replace(/[^a-zA-Z0-9_.-]/g, "_")
              : `allegato_${uid}.pdf`;
            const pdfPath = `invoices/${insertedMessage.id}/${fileName}`;

            const pdfBytes = Uint8Array.from(atob(pdfBase64), (c) => c.charCodeAt(0));
            const { error: uploadError } = await adminClient.storage
              .from("mailbox-attachments")
              .upload(pdfPath, pdfBytes, { contentType: "application/pdf", upsert: true });

            if (uploadError) {
              console.error(`mailbox-sync: upload PDF fallito per UID ${uid}:`, uploadError);
            } else {
              // is_invoice di default true: se Claude non viene consultato
              // (nessuna API key) o fallisce, meglio creare comunque la riga
              // (l'admin la ignora a mano se non era una fattura vera) che
              // perderne una per un errore tecnico.
              let extraction: InvoiceExtraction = {
                amount: null,
                due_date: null,
                description: null,
                is_invoice: true,
              };
              if (ANTHROPIC_API_KEY) {
                try {
                  extraction = await readInvoiceWithClaude(
                    pdfBase64,
                    ANTHROPIC_API_KEY,
                    ANTHROPIC_MODEL,
                  );
                } catch (error) {
                  console.error(
                    `mailbox-sync: lettura Claude della fattura fallita per UID ${uid}:`,
                    error,
                  );
                }
              } else {
                console.error("mailbox-sync: ANTHROPIC_API_KEY assente, fattura salvata senza lettura automatica.");
              }

              if (!extraction.is_invoice) {
                console.log(
                  `mailbox-sync: allegato PDF dell'UID ${uid} non è una fattura (letto da Claude), nessuna riga creata.`,
                );
              } else {
                const { error: invoiceInsertError } = await adminClient
                  .from("mailbox_invoices")
                  .insert({
                    mailbox_message_id: insertedMessage.id,
                    sender: envelope.fromAddress,
                    subject: envelope.subject,
                    amount: extraction.amount,
                    due_date: extraction.due_date,
                    description: extraction.description,
                    pdf_path: pdfPath,
                    status: "da_confermare",
                  });
                if (invoiceInsertError) {
                  console.error(
                    `mailbox-sync: impossibile creare la fattura per UID ${uid}:`,
                    invoiceInsertError,
                  );
                }
              }
            }
          } catch (error) {
            console.error(`mailbox-sync: gestione allegato PDF fallita per UID ${uid}:`, error);
          }
        }

        newLastUid = newLastUid === null ? uid : Math.max(newLastUid, uid);
        processed++;
      } catch (error) {
        // Un singolo messaggio malformato non deve fermare la sincronizzazione
        // degli altri.
        console.error(`mailbox-sync: errore nell'elaborazione dell'UID ${uid}:`, error);
      }
    }

    const recheckedCount = await recheckReadStatus(imap, adminClient);
    console.log(
      `mailbox-sync: ricontrollo letto/non letto completato, ${recheckedCount} messaggi aggiornati.`,
    );

    await imap.logout();
    imap.close();

    await adminClient
      .from("mailbox_sync_state")
      .update({
        last_uid: newLastUid,
        last_synced_at: new Date().toISOString(),
        last_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", 1);

    return jsonResponse({ ok: true, processed, rechecked: recheckedCount });
  } catch (error) {
    // Errori di connessione/autenticazione IMAP: loggati chiaramente e
    // salvati per poterli controllare dall'ultimo stato, senza far fallire
    // in silenzio l'esecuzione né lasciare la connessione a metà.
    console.error("mailbox-sync: errore IMAP:", error);
    imap.close();
    try {
      await adminClient
        .from("mailbox_sync_state")
        .update({
          last_error: error instanceof Error ? error.message : String(error),
          updated_at: new Date().toISOString(),
        })
        .eq("id", 1);
    } catch (_e) {
      // Non critico — l'errore è comunque nei log della function.
    }
    return jsonResponse(
      { error: "Errore di sincronizzazione con la casella email." },
      502,
    );
  }
});

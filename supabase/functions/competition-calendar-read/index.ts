import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// "Gare" — l'admin carica la foto di un calendario gare (bucket privato
// 'competition-sources'), questa funzione la fa leggere a Claude e ritorna
// SOLO l'elenco letto: non scrive nulla nel database. L'admin controlla e
// corregge ogni riga (e aggiunge il link di iscrizione) prima di pubblicare
// con un insert vero in `competitions`, fatto dal client con la sua sessione.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

const GENERIC_ERROR = "Lettura del calendario non disponibile, riprova più tardi.";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function extractJson(text: string): unknown {
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```[a-zA-Z]*\n?/, "").replace(/```\s*$/, "");
  }
  const start = cleaned.indexOf("[");
  const end = cleaned.lastIndexOf("]");
  if (start === -1 || end === -1 || end < start) {
    throw new Error("La risposta del modello non contiene un array JSON.");
  }
  return JSON.parse(cleaned.slice(start, end + 1));
}

async function blobToBase64(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

const PROMPT_TEXT =
  `Questa è una foto o uno screenshot di un calendario di gare (arti marziali: MMA, BJJ/grappling o sambo). Leggi ogni gara elencata.

Rispondi SOLO con un array JSON valido (nessun testo prima o dopo, nessun blocco markdown). Un elemento per gara, con questi campi esatti:
- "name": il nome della gara/evento
- "event_date_start": data di inizio in formato YYYY-MM-DD
- "event_date_end": data di fine in formato YYYY-MM-DD (se la gara dura un solo giorno, usa la stessa data di event_date_start)
- "city": la città/località, o null se non leggibile
- "notes": eventuali altre informazioni utili lette (es. categoria di peso, orario, girone), o null se non ce ne sono

Se una data è ambigua, fai la scelta più plausibile. Se non riesci a leggere una gara con sufficiente certezza, non includerla nell'elenco.`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { image_path } = await req.json();
    if (!image_path || typeof image_path !== "string") {
      return jsonResponse({ error: "image_path è obbligatorio." }, 400);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
    const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") || "claude-sonnet-5";

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SERVICE_ROLE_KEY || !ANTHROPIC_API_KEY) {
      return jsonResponse({ error: GENERIC_ERROR }, 500);
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }

    // Stessa verifica admin usata dalla RLS di scrittura su `competitions`
    // (public.is_admin_from_auth): chi può pubblicare deve poter anche
    // leggere il calendario con questa funzione.
    const { data: isAdmin, error: adminCheckError } = await userClient.rpc(
      "is_admin_from_auth",
    );
    if (adminCheckError || isAdmin !== true) {
      return jsonResponse(
        { error: "Funzione riservata agli amministratori." },
        403,
      );
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: imageBlob, error: downloadError } = await adminClient
      .storage
      .from("competition-sources")
      .download(image_path);
    if (downloadError || !imageBlob) {
      return jsonResponse(
        { error: "Impossibile leggere l'immagine caricata." },
        400,
      );
    }

    const base64Image = await blobToBase64(imageBlob);
    const mediaType = imageBlob.type || "image/jpeg";

    let anthropicResponse: Response;
    try {
      anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: ANTHROPIC_MODEL,
          max_tokens: 2000,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image",
                  source: {
                    type: "base64",
                    media_type: mediaType,
                    data: base64Image,
                  },
                },
                { type: "text", text: PROMPT_TEXT },
              ],
            },
          ],
        }),
      });
    } catch (_error) {
      return jsonResponse({ error: GENERIC_ERROR }, 502);
    }

    if (!anthropicResponse.ok) {
      console.error(
        "competition-calendar-read: Anthropic API error:",
        await anthropicResponse.text(),
      );
      return jsonResponse({ error: GENERIC_ERROR }, 502);
    }

    const anthropicData = await anthropicResponse.json();
    const textBlock = (anthropicData.content ?? []).find(
      (block: { type: string }) => block.type === "text",
    );
    if (!textBlock?.text) {
      return jsonResponse({ error: GENERIC_ERROR }, 502);
    }

    let competitions: Array<{
      name?: string;
      event_date_start?: string;
      event_date_end?: string;
      city?: string | null;
      notes?: string | null;
    }>;
    try {
      const parsed = extractJson(textBlock.text);
      if (!Array.isArray(parsed)) throw new Error("not an array");
      competitions = parsed;
    } catch (_error) {
      return jsonResponse({ error: GENERIC_ERROR }, 502);
    }

    const cleaned = competitions
      .map((row) => ({
        name: String(row.name ?? "").trim(),
        event_date_start: String(row.event_date_start ?? "").trim(),
        event_date_end: String(
          row.event_date_end ?? row.event_date_start ?? "",
        ).trim(),
        city: row.city ? String(row.city).trim() : null,
        notes: row.notes ? String(row.notes).trim() : null,
      }))
      .filter((row) => row.name && row.event_date_start);

    return jsonResponse({ competitions: cleaned });
  } catch (error) {
    console.error("competition-calendar-read error:", error);
    return jsonResponse({ error: GENERIC_ERROR }, 500);
  }
});

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// "Sponsor e Shop": legge lo screenshot del carrello fatto sul sito di uno
// sponsor convenzionato, lo fa leggere a Claude insieme al listino interno
// (senza mai passargli i costi), e calcola qui — mai fidandosi del client —
// il prezzo scontato per le righe in listino e il prezzo pieno per le righe
// fuori listino. Crea l'ordine ('da_confermare') e i suoi costi, e ritorna
// l'ordine senza i costi.

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

function round2(value: number): number {
  return Math.round(value * 100) / 100;
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { sponsor_id, screenshot_path } = await req.json();

    if (!sponsor_id || !screenshot_path) {
      return jsonResponse(
        { error: "sponsor_id e screenshot_path sono obbligatori." },
        400,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SERVICE_ROLE_KEY) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        500,
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }
    const userId = userData.user.id;

    if (!screenshot_path.startsWith(`${userId}/`)) {
      return jsonResponse(
        { error: "Lo screenshot non appartiene all'utente corrente." },
        403,
      );
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
    if (!ANTHROPIC_API_KEY) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        500,
      );
    }
    const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") ||
      "claude-haiku-4-5-20251001";

    const { data: settings, error: settingsError } = await adminClient
      .from("shop_sponsor_settings")
      .select("discount_pct")
      .eq("sponsor_id", sponsor_id)
      .maybeSingle();
    if (settingsError || !settings) {
      return jsonResponse(
        { error: "Lo shop non è configurato per questo sponsor." },
        400,
      );
    }
    const discountPct = Number(settings.discount_pct ?? 20);

    const { data: priceList, error: priceListError } = await adminClient
      .from("shop_price_list")
      .select("model_code, description, color, sizes, cost_price, retail_price")
      .eq("sponsor_id", sponsor_id);
    if (priceListError) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        500,
      );
    }
    const priceRows = priceList ?? [];

    const { data: screenshotBlob, error: downloadError } = await adminClient
      .storage
      .from("shop-carts")
      .download(screenshot_path);
    if (downloadError || !screenshotBlob) {
      return jsonResponse(
        { error: "Impossibile leggere lo screenshot caricato." },
        400,
      );
    }

    const base64Image = await blobToBase64(screenshotBlob);
    const mediaType = screenshotBlob.type || "image/jpeg";

    const catalogForModel = priceRows.map((row) => ({
      model_code: row.model_code,
      descrizione: row.description,
      colore: row.color,
      taglie: row.sizes,
      prezzo_ufficiale: row.retail_price,
    }));

    const promptText =
      `Questo è uno screenshot del carrello di un negozio online. Leggi ogni riga del carrello e il totale.

Listino ufficiale del team (usa descrizione, colore e prezzo per abbinare una riga del carrello a una voce del listino, se corrisponde):
${JSON.stringify(catalogForModel)}

Rispondi SOLO con un array JSON valido (nessun testo prima o dopo, nessun blocco markdown). Un elemento per riga del carrello, con questi campi esatti:
- "descrizione": la descrizione del prodotto letta dallo screenshot
- "taglia": la taglia letta dallo screenshot (stringa, o null se non presente)
- "quantita": la quantità (numero intero)
- "prezzo_letto": il prezzo unitario mostrato sul sito per quella riga (numero)
- "model_code": il model_code del listino se questa riga corrisponde a una voce del listino (per descrizione, colore e prezzo), altrimenti null`;

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
          max_tokens: 1500,
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
                { type: "text", text: promptText },
              ],
            },
          ],
        }),
      });
    } catch (_error) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        502,
      );
    }

    if (!anthropicResponse.ok) {
      console.error("Anthropic API error:", await anthropicResponse.text());
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        502,
      );
    }

    const anthropicData = await anthropicResponse.json();
    const textBlock = (anthropicData.content ?? []).find(
      (block: { type: string }) => block.type === "text",
    );
    if (!textBlock?.text) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        502,
      );
    }

    let cartRows: Array<{
      descrizione?: string;
      taglia?: string | null;
      quantita?: number;
      prezzo_letto?: number;
      model_code?: string | null;
    }>;
    try {
      const parsed = extractJson(textBlock.text);
      if (!Array.isArray(parsed)) throw new Error("not an array");
      cartRows = parsed;
    } catch (_error) {
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        502,
      );
    }

    const priceByModelCode = new Map(
      priceRows
        .filter((row) => !!row.model_code)
        .map((row) => [row.model_code as string, row]),
    );

    const items = [];
    let memberTotal = 0;
    let costTotal = 0;

    for (const row of cartRows) {
      const descrizione = String(row.descrizione ?? "").trim();
      const taglia = row.taglia ? String(row.taglia).trim() : null;
      const quantita = Math.max(1, Math.round(Number(row.quantita ?? 1)));
      const prezzoLetto = Number(row.prezzo_letto ?? 0);
      const modelCode = row.model_code ? String(row.model_code).trim() : null;
      const listinoEntry = modelCode ? priceByModelCode.get(modelCode) : null;

      if (listinoEntry) {
        const retailPrice = Number(listinoEntry.retail_price ?? 0);
        const costPrice = Number(listinoEntry.cost_price ?? 0);
        const prezzoUfficiale = round2(retailPrice * quantita);
        const prezzoAllievo = round2(
          retailPrice * (1 - discountPct / 100) * quantita,
        );
        items.push({
          descrizione,
          model_code: modelCode,
          taglia,
          quantita,
          prezzo_ufficiale: prezzoUfficiale,
          prezzo_allievo: prezzoAllievo,
          in_listino: true,
        });
        memberTotal += prezzoAllievo;
        costTotal += round2(costPrice * quantita);
      } else {
        const prezzoPieno = round2(prezzoLetto * quantita);
        items.push({
          descrizione,
          model_code: null,
          taglia,
          quantita,
          prezzo_ufficiale: prezzoPieno,
          prezzo_allievo: prezzoPieno,
          in_listino: false,
        });
        memberTotal += prezzoPieno;
      }
    }

    memberTotal = round2(memberTotal);
    costTotal = round2(costTotal);
    const margin = round2(memberTotal - costTotal);

    const { data: order, error: insertError } = await adminClient
      .from("shop_orders")
      .insert({
        sponsor_id,
        user_id: userId,
        screenshot_path,
        items,
        member_total: memberTotal,
        status: "da_confermare",
      })
      .select("id, sponsor_id, items, member_total, status, created_at")
      .single();

    if (insertError || !order) {
      console.error("Insert shop_orders error:", insertError);
      return jsonResponse(
        { error: "Lettura del carrello non disponibile, riprova più tardi." },
        500,
      );
    }

    const { error: costsError } = await adminClient
      .from("shop_order_costs")
      .insert({ order_id: order.id, cost_total: costTotal, margin });
    if (costsError) {
      console.error("Insert shop_order_costs error:", costsError);
    }

    return jsonResponse({ order });
  } catch (error) {
    console.error("shop-cart-read error:", error);
    return jsonResponse(
      { error: "Lettura del carrello non disponibile, riprova più tardi." },
      500,
    );
  }
});

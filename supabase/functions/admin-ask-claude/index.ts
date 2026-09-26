import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Client as PgClient } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

// "Chiedi a Claude (dati app)": un admin fa una domanda in linguaggio
// naturale sui dati dell'app, Claude la legge da sé eseguendo query SQL di
// sola lettura tramite il tool "esegui_query" ed elabora la risposta. La
// connessione al database aperta qui è messa subito in modalità READ ONLY
// per l'intera sessione — qualunque tentativo di scrittura, qualunque cosa
// succeda dopo, viene rifiutato dal database stesso, non da un controllo
// applicativo aggirabile.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

const GENERIC_ERROR = "Non riesco a rispondere ora, riprova più tardi.";
const MAX_TOOL_CALLS = 6;
const MAX_ROWS = 50;

const SYSTEM_PROMPT =
  "Sei un assistente per l'amministratore dell'ASD Team Ragnarok, " +
  "rispondi sempre in italiano, in modo diretto e con i numeri richiesti; " +
  "usa il tool esegui_query per leggere i dati che ti servono nel database " +
  "Postgres (schema public), esplorando information_schema se non conosci " +
  "una tabella; non hai memoria di conversazioni precedenti; non puoi " +
  "scrivere né modificare nulla.";

const TOOL_DEFINITION = {
  name: "esegui_query",
  description:
    "Esegue una query SQL di sola lettura (SELECT) sul database Postgres " +
    "(schema public) e ritorna il risultato come JSON (al massimo 50 righe, " +
    "troncato oltre). Usa information_schema per esplorare le tabelle se " +
    "non conosci uno schema. Qualunque tentativo di scrittura viene " +
    "rifiutato dal database: la connessione è di sola lettura.",
  input_schema: {
    type: "object",
    properties: {
      sql: {
        type: "string",
        description: "La query SQL da eseguire.",
      },
    },
    required: ["sql"],
  },
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  let dbClient: PgClient | null = null;

  try {
    const { question } = await req.json();
    if (!question || typeof question !== "string" || !question.trim()) {
      return jsonResponse({ error: "La domanda è obbligatoria." }, 400);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    const SUPABASE_DB_URL = Deno.env.get("SUPABASE_DB_URL");
    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
    const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") || "claude-sonnet-5";

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_DB_URL || !ANTHROPIC_API_KEY) {
      return jsonResponse({ error: GENERIC_ERROR }, 500);
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }
    const userId = userData.user.id;

    const { data: isAdmin, error: adminCheckError } = await userClient.rpc(
      "is_admin_or_secretary_from_auth",
    );
    if (adminCheckError || isAdmin !== true) {
      return jsonResponse(
        { error: "Funzione riservata agli amministratori." },
        403,
      );
    }

    // Connessione diretta al database, subito in sola lettura per l'intera
    // sessione: nessuna scrittura è possibile da qui in avanti, qualunque
    // query arrivi dal tool.
    try {
      dbClient = new PgClient(SUPABASE_DB_URL);
      await dbClient.connect();
      await dbClient.queryArray(
        "SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY;",
      );
    } catch (error) {
      console.error("admin-ask-claude: DB connection error:", error);
      return jsonResponse({ error: GENERIC_ERROR }, 500);
    }

    const eseguiQuery = async (sql: string): Promise<string> => {
      try {
        const result = await dbClient!.queryObject(sql);
        const rows = result.rows.slice(0, MAX_ROWS);
        return JSON.stringify({
          rows,
          row_count: result.rows.length,
          truncated: result.rows.length > MAX_ROWS,
        });
      } catch (error) {
        return JSON.stringify({
          error: error instanceof Error ? error.message : String(error),
        });
      }
    };

    type AnthropicMessage = { role: string; content: unknown };

    const callAnthropic = async (
      messages: AnthropicMessage[],
      includeTool: boolean,
    ) => {
      const body: Record<string, unknown> = {
        model: ANTHROPIC_MODEL,
        max_tokens: 2000,
        system: SYSTEM_PROMPT,
        messages,
      };
      if (includeTool) {
        body.tools = [TOOL_DEFINITION];
      }

      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        console.error("admin-ask-claude: Anthropic API error:", await response.text());
        throw new Error("anthropic_error");
      }

      return await response.json();
    };

    const messages: AnthropicMessage[] = [{ role: "user", content: question }];
    let toolCallCount = 0;
    let finalAnswer = "";

    while (true) {
      const allowTool = toolCallCount < MAX_TOOL_CALLS;
      const response = await callAnthropic(messages, allowTool);
      const content = (response.content ?? []) as Array<Record<string, unknown>>;
      const toolUseBlocks = content.filter((block) => block.type === "tool_use");

      if (allowTool && toolUseBlocks.length > 0) {
        messages.push({ role: "assistant", content });
        const toolResults = [];
        for (const block of toolUseBlocks) {
          toolCallCount++;
          const sql = String((block.input as { sql?: string })?.sql ?? "");
          const result = await eseguiQuery(sql);
          toolResults.push({
            type: "tool_result",
            tool_use_id: block.id,
            content: result,
          });
        }
        messages.push({ role: "user", content: toolResults });
        continue;
      }

      const textBlock = content.find((block) => block.type === "text") as
        | { text?: string }
        | undefined;
      finalAnswer = textBlock?.text?.trim() || GENERIC_ERROR;
      break;
    }

    try {
      await userClient.from("admin_ai_queries").insert({
        user_id: userId,
        question,
        answer: finalAnswer,
      });
    } catch (error) {
      console.error("admin-ask-claude: failed to save history:", error);
      // Not critical — the answer still goes back to the admin.
    }

    return jsonResponse({ answer: finalAnswer });
  } catch (error) {
    console.error("admin-ask-claude error:", error);
    return jsonResponse({ error: GENERIC_ERROR }, 500);
  } finally {
    if (dbClient) {
      try {
        await dbClient.end();
      } catch (_error) {
        // Already closed or never fully connected — nothing to do.
      }
    }
  }
});

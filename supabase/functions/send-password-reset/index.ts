import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_URL = "https://dojomanage9222.builtwithrocket.new";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  try {
    const { email } = await req.json();
    if (!email) {
      return new Response(JSON.stringify({ error: "Email richiesta" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Check if user exists
    const { data: users } = await supabase.auth.admin.listUsers();
    const userExists = users?.users?.some(
      (u: { email?: string }) => u.email?.toLowerCase() === email.toLowerCase()
    );

    if (!userExists) {
      // Return success anyway to avoid email enumeration
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // Generate a secure random token (32 hex chars)
    const tokenBytes = new Uint8Array(32);
    crypto.getRandomValues(tokenBytes);
    const token = Array.from(tokenBytes).map((b) => b.toString(16).padStart(2, "0")).join("");

    // Store token in DB (expires in 1 hour)
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    await supabase.from("password_reset_tokens").insert({
      email: email.toLowerCase(),
      token,
      expires_at: expiresAt,
    });

    // Build reset link — deep link into the app
    const resetLink = `${APP_URL}?reset_token=${token}&email=${encodeURIComponent(email.toLowerCase())}`;

    // Send email via Resend
    const emailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "onboarding@resend.dev",
        to: [email],
        subject: "Team Ragnarok — Reset Password",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; background: #121212; color: #fff; padding: 32px; border-radius: 12px;">
            <h2 style="color: #FF0000; margin-bottom: 8px;">Team Ragnarok</h2>
            <h3 style="color: #fff; margin-bottom: 24px;">Reset della Password</h3>
            <p style="color: #ccc; line-height: 1.6;">
              Hai richiesto il reset della password per il tuo account Team Ragnarok.<br/>
              Usa il codice qui sotto nell'app per impostare una nuova password.
            </p>
            <div style="background: #1E1E1E; border: 2px solid #FF0000; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
              <p style="color: #aaa; font-size: 12px; margin: 0 0 8px;">Il tuo codice di reset (valido 1 ora):</p>
              <p style="color: #FF0000; font-size: 28px; font-weight: bold; letter-spacing: 6px; margin: 0;">${token.substring(0, 8).toUpperCase()}</p>
            </div>
            <p style="color: #888; font-size: 12px; line-height: 1.5;">
              Se non hai richiesto il reset della password, ignora questa email.<br/>
              Il codice scade tra 1 ora.
            </p>
          </div>
        `,
      }),
    });

    if (!emailRes.ok) {
      const errBody = await emailRes.text();
      console.error("Resend error:", errBody);
      throw new Error("Errore nell'invio dell'email");
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

serve(async (req) => {
  // ✅ CORS preflight
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
    const { email, fullName } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: "Email is required" }), {
        status: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

    if (!RESEND_API_KEY) {
      return new Response(
        JSON.stringify({ error: "RESEND_API_KEY not configured" }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    const displayName = fullName || "Nuovo Membro";

    const htmlContent = `
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Benvenuto nel Team Ragnarok</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f4f4;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:30px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color:#c0392b;padding:30px 40px;text-align:center;">
              <h1 style="color:#ffffff;margin:0;font-size:26px;font-weight:bold;letter-spacing:1px;">⚔️ TEAM RAGNAROK</h1>
              <p style="color:#f5b7b1;margin:8px 0 0 0;font-size:14px;">Arti Marziali &amp; Sport da Combattimento</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 30px 40px;">
              <h2 style="color:#2c3e50;font-size:22px;margin:0 0 16px 0;">Benvenuto/a nel Team Ragnarok, ${displayName}!</h2>
              <p style="color:#555555;font-size:15px;line-height:1.7;margin:0 0 20px 0;">
                Siamo lieti di comunicarle che la sua richiesta di iscrizione è stata <strong style="color:#27ae60;">approvata</strong>. 
                Da questo momento può effettuare l'accesso alla piattaforma utilizzando le credenziali registrate.
              </p>

              <!-- Info Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#fdf2f2;border-left:4px solid #c0392b;border-radius:4px;margin-bottom:20px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="color:#2c3e50;font-size:14px;font-weight:bold;margin:0 0 10px 0;">📋 Informazioni importanti:</p>
                    <ul style="color:#555555;font-size:14px;line-height:1.8;margin:0;padding-left:20px;">
                      <li>Il documento accettato in fase di registrazione è disponibile nel suo <strong>profilo</strong>, alla sezione <strong>Documenti</strong>.</li>
                      <li>Se non ha ancora caricato il <strong>certificato medico</strong>, la invitiamo a farlo il prima possibile nell'apposita sezione del profilo. <span style="color:#c0392b;font-weight:bold;">In caso contrario, l'account potrà essere sospeso.</span></li>
                    </ul>
                  </td>
                </tr>
              </table>

              <!-- Annual Membership Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#eaf4fb;border-left:4px solid #2980b9;border-radius:4px;margin-bottom:28px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="color:#2c3e50;font-size:14px;font-weight:bold;margin:0 0 6px 0;">💳 Iscrizione annuale</p>
                    <p style="color:#555555;font-size:14px;line-height:1.7;margin:0;">
                      Prima di procedere all'acquisto di un abbonamento mensile o di un pacchetto, è necessario acquistare l'<strong>iscrizione annuale</strong>. 
                      La invitiamo a completare questo passaggio direttamente dalla sezione <strong>Abbonamenti</strong> del suo profilo.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="color:#555555;font-size:15px;line-height:1.7;margin:0 0 28px 0;">
                Per qualsiasi informazione o necessità, non esiti a contattarci. Siamo a sua disposizione.
              </p>

              <p style="color:#2c3e50;font-size:15px;margin:0;">
                Cordiali saluti,<br/>
                <strong>Lo Staff del Team Ragnarok</strong>
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color:#2c3e50;padding:20px 40px;text-align:center;">
              <p style="color:#95a5a6;font-size:12px;margin:0;">
                © ${new Date().getFullYear()} Team Ragnarok — Tutti i diritti riservati
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "onboarding@resend.dev",
        to: [email],
        subject: "Benvenuto nel Team Ragnarok — Registrazione Approvata",
        html: htmlContent,
      }),
    });

    const resendData = await resendResponse.json();

    if (!resendResponse.ok) {
      console.error("Resend error:", resendData);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: resendData }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    return new Response(
      JSON.stringify({ success: true, messageId: resendData.id }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});

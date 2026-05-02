import { SmtpClient } from 'https://deno.land/x/smtp@v0.7.0/mod.ts';

ensureDenoWriteAllCompat();

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type RejectionEmailBody = {
  email?: string;
  nombre?: string;
  motivo?: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const smtpUser = Deno.env.get('SMTP_USER');
  const smtpPass = Deno.env.get('SMTP_PASS');
  const smtpHost = Deno.env.get('SMTP_HOST') ?? 'smtp.gmail.com';
  const smtpPort = Number(Deno.env.get('SMTP_PORT') ?? '465');
  const mailFrom = Deno.env.get('MAIL_FROM');
  const mailFromAddress = mailFrom ? extractEmailAddress(mailFrom) : null;

  if (!smtpUser || !smtpPass || !smtpHost || !smtpPort || !mailFromAddress) {
    console.error('[send-rejection-email] Secrets SMTP faltantes');
    return jsonResponse({ error: 'Server misconfiguration: missing SMTP secrets' }, 500);
  }

  let body: RejectionEmailBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const email = body.email?.trim();
  const nombre = body.nombre?.trim();
  const motivo = body.motivo?.trim();

  if (!email) {
    return jsonResponse({ error: 'Missing required field: email' }, 400);
  }

  if (!motivo) {
    return jsonResponse({ error: 'Missing required field: motivo' }, 400);
  }

  const client = new SmtpClient();
  try {
    await client.connectTLS({
      hostname: smtpHost,
      port: smtpPort,
      username: smtpUser,
      password: smtpPass,
    });

    await client.send({
      from: mailFromAddress,
      to: email,
      subject: 'AutoResQ - Solicitud de tecnico rechazada',
      content: buildText(nombre, motivo),
      html: buildHtml(nombre, motivo),
    });
  } catch (error) {
    console.error('[send-rejection-email] SMTP error:', error);
    return jsonResponse({ error: 'SMTP send error', detail: toErrorMessage(error) }, 502);
  } finally {
    try {
      await client.close();
    } catch {
      // La conexion puede no existir si falla la autenticacion o el connectTLS.
    }
  }

  console.log(`[send-rejection-email] Enviado a ${email}`);
  return jsonResponse({ ok: true }, 200);
});

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function buildHtml(nombre?: string, motivo?: string): string {
  const safeName = escapeHtml(nombre?.trim() || 'tecnico');
  const safeMotivo = motivo?.trim() ? escapeHtml(motivo.trim()) : '';
  const motivoSection = safeMotivo
    ? `<p><strong>Motivo:</strong></p>
       <blockquote style="border-left:4px solid #BB020F;padding:8px 16px;margin:16px 0;color:#444;">${safeMotivo}</blockquote>`
    : '';

  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:560px;margin:auto;padding:24px;color:#1A1C1D;">
  <h2 style="color:#BB020F;">AutoResQ</h2>
  <p>Hola <strong>${safeName}</strong>,</p>
  <p>Lamentamos informarte que tu solicitud para ser tecnico en <strong>AutoResQ</strong>
     ha sido <strong>rechazada</strong>.</p>
  ${motivoSection}
  <p>Si tienes dudas, puedes contactar al equipo de administracion.</p>
  <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
  <p style="font-size:12px;color:#888;">AutoResQ - Asistencia de confianza en Riobamba</p>
</body>
</html>`;
}

function buildText(nombre?: string, motivo?: string): string {
  const lines = [
    `Hola ${nombre?.trim() || 'tecnico'},`,
    '',
    'Lamentamos informarte que tu solicitud para ser tecnico en AutoResQ ha sido rechazada.',
  ];

  if (motivo?.trim()) {
    lines.push('', `Motivo: ${motivo.trim()}`);
  }

  lines.push('', 'Si tienes dudas, puedes contactar al equipo de administracion.');
  return lines.join('\n');
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function extractEmailAddress(value: string): string | null {
  const trimmed = value.trim();
  const angleMatch = trimmed.match(/<([^>]+)>/);
  return (angleMatch?.[1] ?? trimmed).trim() || null;
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function ensureDenoWriteAllCompat(): void {
  const denoCompat = Deno as typeof Deno & {
    writeAll?: (writer: { write: (data: Uint8Array) => Promise<number> }, data: Uint8Array) => Promise<void>;
  };

  if (typeof denoCompat.writeAll === 'function') {
    return;
  }

  denoCompat.writeAll = async (writer, data) => {
    let written = 0;
    while (written < data.length) {
      written += await writer.write(data.subarray(written));
    }
  };
}

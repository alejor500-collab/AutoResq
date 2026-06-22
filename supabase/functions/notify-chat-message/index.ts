import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type NotifyBody = {
  message_id?: string;
};

type MessageRow = {
  id: string;
  asignacion_id: string;
  remitente_id: string;
  contenido: string;
};

type AssignmentRow = {
  id: string;
  emergencia_id: string;
  emergencias: {
    usuario_id: string;
  } | null;
  tecnicos: {
    usuario_id: string | null;
  } | null;
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: 'Server misconfiguration: missing Supabase service role' },
      500,
    );
  }

  let body: NotifyBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const messageId = body.message_id?.trim();
  if (!messageId) {
    return jsonResponse({ error: 'Missing required field: message_id' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: message, error: messageError } = await supabase
    .from('mensajes')
    .select('id, asignacion_id, remitente_id, contenido')
    .eq('id', messageId)
    .single<MessageRow>();

  if (messageError || !message) {
    console.error('[notify-chat-message] message error:', messageError);
    return jsonResponse({ error: 'Message not found' }, 404);
  }

  const { data: assignment, error: assignmentError } = await supabase
    .from('asignaciones')
    .select('id, emergencia_id, emergencias!inner(usuario_id), tecnicos!tecnico_id(usuario_id)')
    .eq('id', message.asignacion_id)
    .single<AssignmentRow>();

  if (assignmentError || !assignment) {
    console.error('[notify-chat-message] assignment error:', assignmentError);
    return jsonResponse({ error: 'Assignment not found' }, 404);
  }

  const driverUserId = assignment.emergencias?.usuario_id;
  const technicianUserId = assignment.tecnicos?.usuario_id;
  const receiverId = message.remitente_id === driverUserId
    ? technicianUserId
    : driverUserId;

  if (!receiverId) {
    return jsonResponse({ ok: true, push: 'no_receiver' }, 200);
  }

  const title = 'Nuevo mensaje';
  const notificationMessage = 'Tienes un nuevo mensaje en el chat del servicio.';
  const pushResult = await sendPushNotification({
    userId: receiverId,
    title,
    message: notificationMessage,
    emergencyId: assignment.emergencia_id,
  });

  return jsonResponse({ ok: true, push: pushResult }, 200);
});

async function sendPushNotification({
  userId,
  title,
  message,
  emergencyId,
}: {
  userId: string;
  title: string;
  message: string;
  emergencyId: string;
}): Promise<'sent' | 'not_configured' | 'failed'> {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !restApiKey) {
    return 'not_configured';
  }

  const authHeader = restApiKey.startsWith('Key ')
    ? restApiKey
    : `Key ${restApiKey}`;

  try {
    const response = await fetch('https://api.onesignal.com/notifications?c=push', {
      method: 'POST',
      headers: {
        Authorization: authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        app_id: appId,
        include_aliases: { external_id: [userId] },
        target_channel: 'push',
        priority: 10,
        android_visibility: 1,
        existing_android_channel_id: 'autoresq_alerts',
        android_sound: 'default',
        android_accent_color: 'BB020F',
        headings: { en: title, es: title },
        contents: { en: message, es: message },
        data: {
          type: 'nuevo_mensaje',
          emergency_id: emergencyId,
          reference_id: emergencyId,
        },
      }),
    });

    if (!response.ok) {
      console.error(
        '[notify-chat-message] OneSignal error:',
        response.status,
        await response.text(),
      );
      return 'failed';
    }
    return 'sent';
  } catch (error) {
    console.error('[notify-chat-message] OneSignal exception:', error);
    return 'failed';
  }
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

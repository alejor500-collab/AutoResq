import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type NotifyBody = {
  emergency_id?: string;
  type?: string;
};

type EmergencyRow = {
  id: string;
  usuario_id: string;
};

type AssignmentRow = {
  emergencia_id: string;
  estado: string | null;
  tecnicos: {
    usuario_id: string | null;
    usuarios: {
      nombre: string | null;
    } | null;
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

  const emergencyId = body.emergency_id?.trim();
  const type = body.type?.trim();
  if (!emergencyId) {
    return jsonResponse({ error: 'Missing required field: emergency_id' }, 400);
  }
  if (type !== 'solicitud_aceptada') {
    return jsonResponse({ error: 'Unsupported notification type' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: emergency, error: emergencyError } = await supabase
    .from('emergencias')
    .select('id, usuario_id')
    .eq('id', emergencyId)
    .single<EmergencyRow>();

  if (emergencyError || !emergency) {
    console.error('[notify-emergency-update] emergency error:', emergencyError);
    return jsonResponse({ error: 'Emergency not found' }, 404);
  }

  const { data: assignment, error: assignmentError } = await supabase
    .from('asignaciones')
    .select(
      'emergencia_id, estado, tecnicos!tecnico_id(usuario_id, usuarios!usuario_id(nombre))',
    )
    .eq('emergencia_id', emergencyId)
    .in('estado', ['aceptada', 'en_ruta', 'atendiendo'])
    .order('fecha_asignacion', { ascending: false })
    .limit(1)
    .maybeSingle<AssignmentRow>();

  if (assignmentError || !assignment) {
    console.error('[notify-emergency-update] assignment error:', assignmentError);
    return jsonResponse({ error: 'Assignment not found' }, 404);
  }

  const technicianName =
    assignment.tecnicos?.usuarios?.nombre?.trim() || 'Tu tecnico';
  const message = `${technicianName} acepto tu solicitud y ya puede ver tu servicio.`;

  const { error: insertError } = await supabase.from('notificaciones').insert({
    usuario_id: emergency.usuario_id,
    tipo: 'solicitud_aceptada',
    mensaje: message,
    referencia_id: emergencyId,
  });

  if (insertError) {
    console.error('[notify-emergency-update] notification insert error:', insertError);
    return jsonResponse({ error: 'Notification insert failed' }, 500);
  }

  const pushResult = await sendPushNotification({
    userIds: [emergency.usuario_id],
    title: 'Tu solicitud fue aceptada',
    message,
    emergencyId,
    type,
  });

  return jsonResponse({ ok: true, push: pushResult }, 200);
});

async function sendPushNotification({
  userIds,
  title,
  message,
  emergencyId,
  type,
}: {
  userIds: string[];
  title: string;
  message: string;
  emergencyId: string;
  type: string;
}): Promise<'sent' | 'not_configured' | 'failed'> {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !restApiKey || userIds.length === 0) {
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
        include_aliases: { external_id: userIds },
        target_channel: 'push',
        headings: { en: title, es: title },
        contents: { en: message, es: message },
        data: {
          type,
          emergency_id: emergencyId,
        },
      }),
    });

    if (!response.ok) {
      console.error(
        '[notify-emergency-update] OneSignal error:',
        response.status,
        await response.text(),
      );
      return 'failed';
    }
    return 'sent';
  } catch (error) {
    console.error('[notify-emergency-update] OneSignal exception:', error);
    return 'failed';
  }
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

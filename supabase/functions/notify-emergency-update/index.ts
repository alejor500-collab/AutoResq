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

type PushRecipient = {
  userId: string;
  title: string;
  message: string;
  type: string;
};

const supportedTypes = new Set([
  'solicitud_aceptada',
  'tecnico_en_ruta',
  'servicio_finalizado',
  'solicitud_cancelada',
  'tecnico_cancelo',
]);

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
  if (!type || !supportedTypes.has(type)) {
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

  const assignmentStates = type === 'servicio_finalizado'
    ? ['finalizada']
    : type === 'solicitud_cancelada' || type === 'tecnico_cancelo'
    ? ['aceptada', 'en_ruta', 'atendiendo', 'rechazada', 'finalizada']
    : ['aceptada', 'en_ruta', 'atendiendo'];

  const { data: assignment, error: assignmentError } = await supabase
    .from('asignaciones')
    .select(
      'emergencia_id, estado, tecnicos!tecnico_id(usuario_id, usuarios!usuario_id(nombre))',
    )
    .eq('emergencia_id', emergencyId)
    .in('estado', assignmentStates)
    .order('fecha_asignacion', { ascending: false })
    .limit(1)
    .maybeSingle<AssignmentRow>();

  if (assignmentError || !assignment) {
    console.error('[notify-emergency-update] assignment error:', assignmentError);
    return jsonResponse({ error: 'Assignment not found' }, 404);
  }

  const recipients = buildRecipients({ type, emergency, assignment });

  for (const recipient of recipients) {
    const { data: existingNotification } = await supabase
      .from('notificaciones')
      .select('id')
      .eq('usuario_id', recipient.userId)
      .eq('tipo', recipient.type)
      .eq('referencia_id', emergencyId)
      .maybeSingle<{ id: string }>();

    if (!existingNotification) {
      const { error: insertError } = await supabase.from('notificaciones').insert({
        usuario_id: recipient.userId,
        tipo: recipient.type,
        mensaje: recipient.message,
        referencia_id: emergencyId,
      });

      if (insertError) {
        console.error('[notify-emergency-update] notification insert error:', insertError);
        return jsonResponse({ error: 'Notification insert failed' }, 500);
      }
    }
  }

  const pushResult = await sendPushNotification({
    recipients,
    emergencyId,
  });

  return jsonResponse({ ok: true, push: pushResult }, 200);
});

function buildRecipients({
  type,
  emergency,
  assignment,
}: {
  type: string;
  emergency: EmergencyRow;
  assignment: AssignmentRow;
}): PushRecipient[] {
  const technicianName =
    assignment.tecnicos?.usuarios?.nombre?.trim() || 'Tu tecnico';
  const technicianUserId = assignment.tecnicos?.usuario_id;

  switch (type) {
    case 'solicitud_aceptada':
      return [{
        userId: emergency.usuario_id,
        type,
        title: 'Tu solicitud fue aceptada',
        message: `${technicianName} acepto tu solicitud y ya puede ver tu servicio.`,
      }];
    case 'tecnico_en_ruta':
      return [{
        userId: emergency.usuario_id,
        type,
        title: 'Tecnico en camino',
        message: `${technicianName} ya llego a tu ubicacion y comenzo la atencion.`,
      }];
    case 'servicio_finalizado':
      return [{
        userId: emergency.usuario_id,
        type,
        title: 'Servicio finalizado',
        message:
          `${technicianName} marco el servicio como finalizado. Ya puedes calificar la atencion.`,
      }];
    case 'tecnico_cancelo':
      return [{
        userId: emergency.usuario_id,
        type,
        title: 'El tecnico cancelo',
        message:
          'El tecnico tuvo que cancelar la atencion. Tu solicitud vuelve a estar disponible para que otro tecnico pueda ayudarte.',
      }];
    case 'solicitud_cancelada':
      if (!technicianUserId) return [];
      return [{
        userId: technicianUserId,
        type,
        title: 'Solicitud cancelada',
        message:
          'El conductor cancelo la solicitud. Ya no es necesario atender este servicio.',
      }];
    default:
      return [];
  }
}

async function sendPushNotification({
  recipients,
  emergencyId,
}: {
  recipients: PushRecipient[];
  emergencyId: string;
}): Promise<'sent' | 'not_configured' | 'failed'> {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !restApiKey || recipients.length === 0) {
    return 'not_configured';
  }

  const authHeader = restApiKey.startsWith('Key ')
    ? restApiKey
    : `Key ${restApiKey}`;

  try {
    for (const recipient of recipients) {
      const response = await fetch('https://api.onesignal.com/notifications?c=push', {
        method: 'POST',
        headers: {
          Authorization: authHeader,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          app_id: appId,
          include_aliases: { external_id: [recipient.userId] },
          target_channel: 'push',
          priority: 10,
          android_visibility: 1,
          headings: { en: recipient.title, es: recipient.title },
          contents: { en: recipient.message, es: recipient.message },
          data: {
            type: recipient.type,
            emergency_id: emergencyId,
            reference_id: emergencyId,
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

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type NotifyBody = {
  emergency_id?: string;
};

type EmergencyRow = {
  id: string;
  usuario_id: string;
  descripcion: string | null;
  ai_emergency_type: string | null;
  clasificacion_ia: string | null;
};

type TechnicianRow = {
  usuario_id: string | null;
  especialidad: string | null;
  ubicacion_lat: number | null;
  ubicacion_lng: number | null;
  calificacion_promedio: number | null;
};

type EmergencyLocationRow = {
  direccion: string | null;
  latitud: number | null;
  longitud: number | null;
};

const specialtyCatalog = {
  mechanical_quick: ['Mecánica rápida', 'minor_mechanic', 'engine', 'overheating', 'brakes'],
  battery_electrical: [
    'Sistema eléctrico y batería',
    'battery_jumpstart',
    'battery',
    'electrical',
  ],
  tires_vulcanization: [
    'Llantas y vulcanización',
    'tire_change',
    'flat_tire_no_spare',
    'tire',
  ],
  tow_truck: ['Grúa / remolque', 'tow_service', 'accident'],
  fuel_delivery: ['Combustible', 'fuel_delivery', 'fuel'],
  vehicle_locksmith: ['Cerrajería vehicular', 'locksmith_vehicle', 'lockout'],
  general_assistance: ['Auxilio general', 'unknown', 'not_emergency'],
} as const;

const validSpecialtyCodes = new Set(Object.keys(specialtyCatalog));

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
  if (!emergencyId) {
    return jsonResponse({ error: 'Missing required field: emergency_id' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: emergency, error: emergencyError } = await supabase
    .from('emergencias')
    .select('id, usuario_id, descripcion, ai_emergency_type, clasificacion_ia')
    .eq('id', emergencyId)
    .single<EmergencyRow>();

  if (emergencyError || !emergency) {
    console.error('[notify-new-emergency] emergency error:', emergencyError);
    return jsonResponse({ error: 'Emergency not found' }, 404);
  }

  const [{ data: location }, { data: driver }, { data: technicians }] =
    await Promise.all([
      supabase
        .from('ubicaciones')
        .select('direccion, latitud, longitud')
        .eq('emergencia_id', emergencyId)
        .maybeSingle<EmergencyLocationRow>(),
      supabase
        .from('usuarios')
        .select('nombre')
        .eq('id', emergency.usuario_id)
        .maybeSingle<{ nombre: string | null }>(),
      supabase
        .from('tecnicos')
        .select('usuario_id, especialidad, ubicacion_lat, ubicacion_lng, calificacion_promedio')
        .eq('estado_verificacion', 'aprobado')
        .eq('disponible', true)
        .neq('usuario_id', emergency.usuario_id),
    ]);

  const availableTechnicians = ((technicians ?? []) as TechnicianRow[]).filter(
    (technician) => Boolean(technician.usuario_id),
  );
  if (availableTechnicians.length === 0) {
    return jsonResponse({ ok: true, recipients: 0, push: 'no_available_technicians' }, 200);
  }

  const emergencyType = emergency.ai_emergency_type ?? emergency.clasificacion_ia;
  const specialtyMatches = availableTechnicians.filter((technician) =>
    specialtyMatchesEmergencyType(technician.especialidad, emergencyType),
  );
  const compatibleTechnicians = specialtyMatches.length > 0
    ? specialtyMatches
    : availableTechnicians;
  const recipients = rankAndFilterRecipients({
    technicians: compatibleTechnicians,
    emergencyType,
    emergencyLat: location?.latitud ?? null,
    emergencyLng: location?.longitud ?? null,
  });

  if (recipients.length === 0) {
    return jsonResponse({ ok: true, recipients: 0, push: 'no_technicians_in_range' }, 200);
  }

  const { data: existingNotifications } = await supabase
    .from('notificaciones')
    .select('usuario_id')
    .eq('referencia_id', emergencyId)
    .eq('tipo', 'nueva_solicitud');
  const existingIds = new Set(
    ((existingNotifications ?? []) as Array<{ usuario_id: string | null }>)
      .map((row) => row.usuario_id)
      .filter(Boolean) as string[],
  );

  const pushRecipientIds = recipients
    .map((technician) => technician.usuario_id)
    .filter(Boolean) as string[];
  const newRecipients = recipients.filter(
    (technician) => technician.usuario_id && !existingIds.has(technician.usuario_id),
  );

  const serviceName = serviceNameForType(emergencyType);
  const driverName = driver?.nombre?.trim() || 'Conductor';
  const address = location?.direccion?.trim() || 'Ubicacion del conductor';
  const message = `${serviceName}: ${driverName} necesita asistencia en ${address}.`;

  if (newRecipients.length > 0) {
    const rows = newRecipients.map((technician) => ({
      usuario_id: technician.usuario_id,
      tipo: 'nueva_solicitud',
      mensaje: message,
      referencia_id: emergencyId,
    }));

    const { error: insertError } = await supabase.from('notificaciones').insert(rows);
    if (insertError) {
      console.error('[notify-new-emergency] notification insert error:', insertError);
      return jsonResponse({ error: 'Notification insert failed' }, 500);
    }
  }

  const pushResult = await sendPushNotification({
    userIds: pushRecipientIds,
    title: 'Nueva solicitud en AutoResQ',
    message,
    emergencyId,
  });

  return jsonResponse(
    {
      ok: true,
      recipients: pushRecipientIds.length,
      inserted: newRecipients.length,
      push: pushResult,
    },
    200,
  );
});

async function sendPushNotification({
  userIds,
  title,
  message,
  emergencyId,
}: {
  userIds: string[];
  title: string;
  message: string;
  emergencyId: string;
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
          type: 'nueva_solicitud',
          emergency_id: emergencyId,
        },
      }),
    });

    if (!response.ok) {
      console.error(
        '[notify-new-emergency] OneSignal error:',
        response.status,
        await response.text(),
      );
      return 'failed';
    }
    return 'sent';
  } catch (error) {
    console.error('[notify-new-emergency] OneSignal exception:', error);
    return 'failed';
  }
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function specialtyMatchesEmergencyType(
  specialty: string | null,
  type: string | null,
): boolean {
  const normalizedSpecialty = (specialty ?? '').trim();
  if (!validSpecialtyCodes.has(normalizedSpecialty)) return false;
  const emergencyType = (type ?? 'unknown').trim();
  return specialtyCatalog[
    normalizedSpecialty as keyof typeof specialtyCatalog
  ].includes(emergencyType);
}

function rankAndFilterRecipients({
  technicians,
  emergencyType,
  emergencyLat,
  emergencyLng,
}: {
  technicians: TechnicianRow[];
  emergencyType: string | null;
  emergencyLat: number | null;
  emergencyLng: number | null;
}): TechnicianRow[] {
  const annotated = technicians
    .map((technician) => {
      const distanceKm = distanceInKm(
        emergencyLat,
        emergencyLng,
        technician.ubicacion_lat,
        technician.ubicacion_lng,
      );
      const band = distanceBand(emergencyType, distanceKm);
      return { technician, distanceKm, band };
    })
    .filter((entry) => entry.band !== null);

  const hasNearby = annotated.some((entry) => entry.band!.rank <= 1);
  return annotated
    .filter((entry) => entry.band!.rank <= 1 || !hasNearby)
    .sort((a, b) => {
      const bandCompare = a.band!.rank - b.band!.rank;
      if (bandCompare !== 0) return bandCompare;
      const ratingCompare =
        (b.technician.calificacion_promedio ?? 0) -
        (a.technician.calificacion_promedio ?? 0);
      if (ratingCompare !== 0) return ratingCompare;
      return (a.distanceKm ?? Number.POSITIVE_INFINITY) -
        (b.distanceKm ?? Number.POSITIVE_INFINITY);
    })
    .map((entry) => entry.technician);
}

function distanceBand(
  emergencyType: string | null,
  distanceKm: number | null,
): { rank: number; maxKm: number } | null {
  if (distanceKm === null) return { rank: 2, maxKm: 0 };
  if (distanceKm < 0) return null;

  const normalizedType = (emergencyType ?? '').trim();
  if (specialtyCatalog.tow_truck.some((value) => value === normalizedType)) {
    if (distanceKm <= 10) return { rank: 0, maxKm: 10 };
    if (distanceKm <= 20) return { rank: 1, maxKm: 20 };
    return null;
  }

  if (distanceKm <= 5) return { rank: 0, maxKm: 5 };
  if (distanceKm <= 10) return { rank: 1, maxKm: 10 };
  if (distanceKm <= 15) return { rank: 2, maxKm: 15 };
  return null;
}

function distanceInKm(
  latA: number | null,
  lngA: number | null,
  latB: number | null,
  lngB: number | null,
): number | null {
  if (latA === null || lngA === null || latB === null || lngB === null) {
    return null;
  }
  const earthRadiusKm = 6371;
  const dLat = toRadians(latB - latA);
  const dLng = toRadians(lngB - lngA);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(latA)) *
      Math.cos(toRadians(latB)) *
      Math.sin(dLng / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRadians(value: number): number {
  return value * Math.PI / 180;
}

function serviceNameForType(type: string | null): string {
  switch (type) {
    case 'Mecánica rápida':
    case 'Sistema eléctrico y batería':
    case 'Llantas y vulcanización':
    case 'Grúa / remolque':
    case 'Combustible':
    case 'Cerrajería vehicular':
    case 'Auxilio general':
      return type;
    case 'tire_change':
      return 'Cambio de llanta';
    case 'flat_tire_no_spare':
      return 'Rueda pinchada';
    case 'battery_jumpstart':
      return 'Paso de corriente';
    case 'tow_service':
      return 'Grua / remolque';
    case 'locksmith_vehicle':
      return 'Apertura de vehiculo';
    case 'fuel_delivery':
      return 'Entrega de combustible';
    case 'minor_mechanic':
      return 'Mecanica menor';
    default:
      return 'Emergencia automotriz';
  }
}

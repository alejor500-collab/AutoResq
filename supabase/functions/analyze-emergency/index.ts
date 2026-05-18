const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses';
const DEFAULT_MODEL = 'gpt-5.4-mini';
const MAX_DESCRIPTION_LENGTH = 1800;

type AnalyzeEmergencyBody = {
  description?: string;
  location?: string;
  vehicle_type?: string;
  plate?: string;
  brand_model?: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const apiKey = Deno.env.get('OPENAI_API_KEY');
  const model = Deno.env.get('OPENAI_MODEL') || DEFAULT_MODEL;

  if (!apiKey) {
    return jsonResponse(
      { error: 'Server misconfiguration: missing OPENAI_API_KEY' },
      500,
    );
  }

  let body: AnalyzeEmergencyBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const description = body.description?.trim();
  if (!description) {
    return jsonResponse({ error: 'Missing required field: description' }, 400);
  }

  const safeDescription = description.slice(0, MAX_DESCRIPTION_LENGTH);

  try {
    const response = await fetch(OPENAI_RESPONSES_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: [
                  'Eres un asistente tecnico interno de AutoResQ.',
                  'Responde siempre en espanol.',
                  'Analiza unicamente emergencias vehiculares.',
                  'No des diagnosticos definitivos ni reemplaces al tecnico.',
                  'Nunca devuelvas precios, costos, tarifas, rangos, montos ni formulas de cobro.',
                  'La IA solo clasifica el tipo de emergencia y resume informacion util; Supabase calcula cualquier precio.',
                  'Prioriza la seguridad.',
                  'Si hay humo, fuego, fuga de combustible, choque, heridos, falla electrica grave, frenos comprometidos o sobrecalentamiento severo, aumenta la prioridad.',
                  'No incluyas riesgos menores como noche, lugar inseguro, poca iluminacion o lluvia ligera.',
                  'No des instrucciones mecanicas complejas al conductor.',
                  'Devuelve unicamente JSON valido segun el esquema.',
                  'La respuesta debe ser corta, util y operativa.',
                ].join(' '),
              },
            ],
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: buildUserInput(safeDescription, body),
              },
            ],
          },
        ],
        text: {
          format: {
            type: 'json_schema',
            name: 'autoresq_emergency_analysis',
            strict: true,
            schema: analysisSchema,
          },
        },
        max_output_tokens: 350,
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      const openAiError = parseOpenAiError(detail);
      console.error('[analyze-emergency] OpenAI error:', detail);
      return jsonResponse(
        {
          error: 'OpenAI analysis failed',
          reason: openAiError.code,
          detail: openAiError.message,
        },
        openAiError.httpStatus,
      );
    }

    const payload = await response.json();
    const text = extractOutputText(payload);
    if (!text) {
      console.error('[analyze-emergency] Empty structured output:', payload);
      return jsonResponse({ error: 'Empty AI response' }, 502);
    }

    const parsed = JSON.parse(text);
    return jsonResponse(parsed, 200);
  } catch (error) {
    console.error('[analyze-emergency] Unexpected error:', error);
    return jsonResponse(
      { error: 'Emergency analysis error', detail: toErrorMessage(error) },
      500,
    );
  }
});

function buildUserInput(
  description: string,
  body: AnalyzeEmergencyBody,
): string {
  const context = [
    `Descripcion del conductor: ${description}`,
    body.location ? `Ubicacion: ${body.location}` : null,
    body.vehicle_type ? `Tipo de vehiculo: ${body.vehicle_type}` : null,
    body.plate ? `Placa: ${body.plate}` : null,
    body.brand_model ? `Marca/modelo: ${body.brand_model}` : null,
  ].filter(Boolean);

  return `${context.join('\n')}\n\nClasifica con estas reglas:
- Si no describe una emergencia vehicular: is_valid_emergency=false, emergency_type_code=not_emergency, priority=low.
- Si es ambiguo pero vehicular: emergency_type_code=unknown y prioridad segun riesgo.
- Si el conductor pide grua, remolque o traslado del vehiculo: emergency_type_code=tow_service.
- Si habla de rueda pinchada, llanta pinchada o cambio de llanta y dice que tiene repuesto o llanta de emergencia: emergency_type_code=tire_change.
- Si habla de rueda/llanta pinchada y no tiene repuesto, no lo menciona o no esta claro: emergency_type_code=flat_tire_no_spare.
- Si es bateria descargada o paso de corriente: emergency_type_code=battery_jumpstart.
- Si es falta de combustible: emergency_type_code=fuel_delivery.
- Si dejo llaves adentro o necesita apertura del vehiculo: emergency_type_code=locksmith_vehicle.
- Si es falla mecanica no claramente identificada: emergency_type_code=minor_mechanic.
- Riesgos graves usan priority high o critical segun gravedad.
- Llanta baja/pinchada sin riesgo adicional normalmente medium.
- Bateria descargada o vehiculo no enciende sin otros riesgos normalmente medium.
- Perdida de llaves/cierre sin riesgo normalmente low o medium.
- important_risks solo debe incluir riesgos realmente relevantes: vehiculo inmovilizado en via, posible accidente, fuga de combustible, humo, bloqueo de transito, riesgo electrico o dano severo visible.
- No incluyas precio, costo, tarifa ni monto en ningun campo.`;
}

function extractOutputText(payload: {
  output_text?: string;
  output?: Array<{
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
}): string | null {
  if (typeof payload.output_text === 'string') {
    return payload.output_text;
  }

  for (const item of payload.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === 'output_text' && typeof content.text === 'string') {
        return content.text;
      }
    }
  }

  return null;
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function toErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function parseOpenAiError(detail: string): {
  code: string;
  message: string;
  httpStatus: number;
} {
  try {
    const parsed = JSON.parse(detail) as {
      error?: { code?: string; message?: string };
    };
    const code = parsed.error?.code ?? 'openai_error';
    const message = parsed.error?.message ?? 'OpenAI request failed';
    return {
      code,
      message,
      httpStatus:
        code === 'insufficient_quota' ? 503 : 502,
    };
  } catch {
    return {
      code: 'openai_error',
      message: detail || 'OpenAI request failed',
      httpStatus: 502,
    };
  }
}

const analysisSchema = {
  type: 'object',
  properties: {
    is_valid_emergency: { type: 'boolean' },
    emergency_type_code: {
      type: 'string',
      enum: [
        'tire_change',
        'flat_tire_no_spare',
        'battery_jumpstart',
        'tow_service',
        'minor_mechanic',
        'locksmith_vehicle',
        'fuel_delivery',
        'unknown',
        'not_emergency',
      ],
    },
    priority: {
      type: 'string',
      enum: ['low', 'medium', 'high', 'critical'],
    },
    user_friendly_summary: { type: 'string' },
    safety_recommendation: { type: 'string' },
    technician_summary: { type: 'string' },
    important_risks: {
      type: 'array',
      items: {
        type: 'string',
        enum: [
          'vehicle_disabled_in_road',
          'possible_accident',
          'traffic_blockage',
          'severe_visible_damage',
          'smoke',
          'fire',
          'fuel_leak',
          'injury',
          'crash',
          'electrical_risk',
          'brake_failure',
          'severe_overheating',
          'none',
        ],
      },
    },
    requires_immediate_attention: { type: 'boolean' },
    confidence: { type: 'number' },
  },
  required: [
    'is_valid_emergency',
    'emergency_type_code',
    'priority',
    'user_friendly_summary',
    'safety_recommendation',
    'technician_summary',
    'important_risks',
    'requires_immediate_attention',
    'confidence',
  ],
  additionalProperties: false,
} as const;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const GITHUB_MODELS_BASE_URL = 'https://models.github.ai';
const GITHUB_API_VERSION = '2026-03-10';
const GITHUB_DEFAULT_MODEL = 'openai/gpt-4.1-mini';
const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses';
const OPENAI_DEFAULT_MODEL = 'gpt-5.4-mini';
const MIN_DESCRIPTION_LENGTH = 8;
const MAX_DESCRIPTION_LENGTH = 1800;
const MAX_OUTPUT_TOKENS = 700;

const ALLOWED_CATEGORIES = [
  'Mecánica rápida',
  'Sistema eléctrico y batería',
  'Llantas y vulcanización',
  'Grúa / remolque',
  'Combustible',
  'Cerrajería vehicular',
  'Auxilio general',
] as const;

const ALLOWED_URGENCIES = ['baja', 'media', 'alta'] as const;

type AllowedCategory = typeof ALLOWED_CATEGORIES[number];
type AllowedUrgency = typeof ALLOWED_URGENCIES[number];

type AnalyzeEmergencyBody = {
  description?: string;
  location?: string;
  vehicle_type?: string;
  plate?: string;
  brand_model?: string;
  image_urls?: string[];
};

type EmergencyAnalysis = {
  categoria: AllowedCategory;
  tipo_danio: string;
  resumen_tecnico: string;
  urgencia: AllowedUrgency;
  requiere_grua: boolean;
  recomendacion: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const githubApiKey =
    Deno.env.get('GITHUB_MODELS_TOKEN') ?? Deno.env.get('GITHUB_TOKEN');
  const githubModel = Deno.env.get('GITHUB_MODEL') ?? GITHUB_DEFAULT_MODEL;
  const githubOrg = Deno.env.get('GITHUB_MODELS_ORG')?.trim();
  const openAiContingencyApiKey =
    Deno.env.get('OPENAI_CONTINGENCY_API_KEY') ??
    Deno.env.get('OPENAI_API_KEY');
  const openAiContingencyModel =
    Deno.env.get('OPENAI_CONTINGENCY_MODEL') ??
    Deno.env.get('OPENAI_MODEL') ??
    OPENAI_DEFAULT_MODEL;

  if (!githubApiKey && !openAiContingencyApiKey) {
    return jsonResponse(
      {
        error:
          'Server misconfiguration: missing GitHub Models token and OpenAI contingency key',
      },
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
    return jsonResponse(
      { error: 'Describe brevemente que ocurre con el vehiculo.' },
      400,
    );
  }
  if (description.length < MIN_DESCRIPTION_LENGTH) {
    return jsonResponse(
      { error: 'Agrega un poco mas de detalle sobre el problema.' },
      400,
    );
  }

  const safeDescription = description.slice(0, MAX_DESCRIPTION_LENGTH);

  try {
    if (githubApiKey) {
      const githubResult = await runGitHubModelsAnalysis({
        apiKey: githubApiKey,
        model: githubModel,
        githubOrg,
        body,
        description: safeDescription,
      });
      if (githubResult) {
        return jsonResponse(githubResult, 200);
      }
      if (hasEvidenceImages(body)) {
        const githubTextOnlyResult = await runGitHubModelsAnalysis({
          apiKey: githubApiKey,
          model: githubModel,
          githubOrg,
          body: withoutEvidenceImages(body),
          description: safeDescription,
        });
        if (githubTextOnlyResult) {
          return jsonResponse(githubTextOnlyResult, 200);
        }
      }
    }

    if (openAiContingencyApiKey) {
      console.warn(
        '[analyze-emergency] Falling back to OpenAI contingency provider.',
      );
      const openAiResult = await runOpenAiContingencyAnalysis({
        apiKey: openAiContingencyApiKey,
        model: openAiContingencyModel,
        body,
        description: safeDescription,
      });
      if (openAiResult) {
        return jsonResponse(openAiResult, 200);
      }
      if (hasEvidenceImages(body)) {
        const openAiTextOnlyResult = await runOpenAiContingencyAnalysis({
          apiKey: openAiContingencyApiKey,
          model: openAiContingencyModel,
          body: withoutEvidenceImages(body),
          description: safeDescription,
        });
        if (openAiTextOnlyResult) {
          return jsonResponse(openAiTextOnlyResult, 200);
        }
      }
    }

    return jsonResponse(buildFallbackAnalysis(safeDescription), 200);
  } catch (error) {
    console.error('[analyze-emergency] Unexpected error:', error);
    return jsonResponse(buildFallbackAnalysis(safeDescription), 200);
  }
});

async function runGitHubModelsAnalysis({
  apiKey,
  model,
  githubOrg,
  body,
  description,
}: {
  apiKey: string;
  model: string;
  githubOrg?: string;
  body: AnalyzeEmergencyBody;
  description: string;
}): Promise<EmergencyAnalysis | null> {
  const endpoint = githubOrg
    ? `${GITHUB_MODELS_BASE_URL}/orgs/${githubOrg}/inference/chat/completions`
    : `${GITHUB_MODELS_BASE_URL}/inference/chat/completions`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'X-GitHub-Api-Version': GITHUB_API_VERSION,
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: buildSystemPrompt(),
        },
        {
          role: 'user',
          content: buildChatUserContent(description, body),
        },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'autoresq_vehicle_diagnostic',
          schema: analysisSchema,
        },
      },
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0.2,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    const providerError = parseProviderError(detail, 'github_models_error');
    console.error('[analyze-emergency] GitHub Models error:', providerError);
    return null;
  }

  const payload = await response.json();
  const text = extractChatCompletionsOutputText(payload);
  return safeParseAnalysis(text, description);
}

async function runOpenAiContingencyAnalysis({
  apiKey,
  model,
  body,
  description,
}: {
  apiKey: string;
  model: string;
  body: AnalyzeEmergencyBody;
  description: string;
}): Promise<EmergencyAnalysis | null> {
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
              text: buildSystemPrompt(),
            },
          ],
        },
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: buildUserInput(description, body),
            },
            ...buildOpenAiImageInput(body),
          ],
        },
      ],
      text: {
        format: {
          type: 'json_schema',
          name: 'autoresq_vehicle_diagnostic',
          strict: true,
          schema: analysisSchema,
        },
      },
      max_output_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0.2,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    const providerError = parseProviderError(detail, 'openai_contingency_error');
    console.error('[analyze-emergency] OpenAI contingency error:', providerError);
    return null;
  }

  const payload = await response.json();
  const text = extractOpenAiResponsesOutputText(payload);
  return safeParseAnalysis(text, description);
}

function buildSystemPrompt(): string {
  return [
    'Eres el asistente de diagnóstico vehicular para emergencias de AutoResQ.',
    'Analiza solo la información proporcionada por el conductor, aunque venga en lenguaje informal, breve, incompleto o con errores de escritura.',
    'No rechaces descripciones libres: interpreta síntomas, necesidades o contexto y clasifica prudentemente.',
    'Si se adjuntan fotos, úsalas solo como apoyo visual y no inventes datos que no sean visibles o reportados.',
    'No inventes síntomas, causas, piezas dañadas, contexto, kilometraje ni antecedentes.',
    'No des diagnósticos definitivos; entrega solo una orientación inicial prudente.',
    'Tu respuesta debe ser exclusivamente JSON válido, sin markdown, sin texto extra, sin explicaciones y sin bloques de código.',
    'Debes usar exactamente una de estas categorías para "categoria":',
    ALLOWED_CATEGORIES.map((value) => `"${value}"`).join(', '),
    'La categoría representa el rol principal del técnico que debe atender la solicitud, no solo el nombre de la falla.',
    'Clasifica por capacidad requerida: "Mecánica rápida" para fallas revisables en sitio por mecánico móvil; "Sistema eléctrico y batería" para problemas principalmente eléctricos, batería, arranque o carga; "Llantas y vulcanización" para neumáticos; "Grúa / remolque" cuando el vehículo no debe o no puede circular de forma segura y la atención principal sea traslado/remolque; "Combustible" para falta o error de combustible; "Cerrajería vehicular" para acceso o llaves; "Auxilio general" solo si no hay información suficiente para escoger un rol.',
    'Si el caso requiere traslado/remolque como servicio principal, "categoria" debe ser "Grúa / remolque" y "requiere_grua" debe ser true.',
    'Si eliges una categoría diferente de "Grúa / remolque", "requiere_grua" debe ser false, salvo que el conductor pida explícitamente remolque adicional.',
    '"tipo_danio" es la explicación para el conductor. Escribe 2 o 3 frases claras, entre 35 y 70 palabras: indica qué sistema podría estar afectado, qué significan los síntomas reportados y por qué conviene una revisión. Usa lenguaje cotidiano y aclara que es una evaluación preliminar, no un diagnóstico definitivo.',
    '"resumen_tecnico" es información operativa para el técnico. Escribe entre 70 y 130 palabras en un solo párrafo compacto. Incluye síntomas y contexto aportados; una o dos hipótesis compatibles ordenadas por probabilidad; sistemas que conviene inspeccionar primero; comprobaciones iniciales; riesgos; y datos que faltan por confirmar.',
    'Para "resumen_tecnico", prioriza señales accionables: ruidos, fugas, perdida de potencia, temperatura, bateria, llanta, frenos, transmision, embrague, direccion, luces o inmovilizacion, segun aplique.',
    'Diferencia explícitamente lo reportado de lo inferido. Usa expresiones prudentes como "compatible con", "podría relacionarse con" o "confirmar". No afirmes que una pieza está dañada sin evidencia suficiente.',
    'No repitas literalmente la explicación del conductor en "resumen_tecnico". Si hay poca información, explica qué preguntas o verificaciones permitirán distinguir las causas probables.',
    '"urgencia" solo puede ser "baja", "media" o "alta".',
    '"requiere_grua" debe ser true solo cuando el rol requerido sea grua/remolque o el conductor indique claramente que necesita remolque.',
    '"recomendacion" debe contener 2 o 3 instrucciones concretas, entre 25 y 55 palabras: qué hacer ahora, qué evitar y qué señal justificaría alejarse del vehículo o pedir atención urgente. No sugieras reparaciones peligrosas para el conductor.',
    'Si la descripción es ambigua o insuficiente, usa "Auxilio general".',
    'No incluyas precios, costos, tarifas, tiempos, promesas ni información no solicitada.',
  ].join(' ');
}

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
    body.image_urls?.length
      ? `Fotos adjuntas: ${Math.min(body.image_urls.length, 2)} imagen(es) de evidencia.`
      : null,
  ].filter(Boolean);

  return `${context.join('\n')}\n\nDevuelve exactamente un objeto JSON con esta forma:
{
  "categoria": "",
  "tipo_danio": "",
  "resumen_tecnico": "",
  "urgencia": "baja | media | alta",
  "requiere_grua": true | false,
  "recomendacion": ""
}`;
}

function buildChatUserContent(
  description: string,
  body: AnalyzeEmergencyBody,
):
  | string
  | Array<
    | { type: 'text'; text: string }
    | { type: 'image_url'; image_url: { url: string } }
  > {
  const text = buildUserInput(description, body);
  const imageUrls = sanitizeImageUrls(body.image_urls);
  if (imageUrls.length === 0) return text;
  return [
    { type: 'text', text },
    ...imageUrls.map((url) => ({
      type: 'image_url' as const,
      image_url: { url },
    })),
  ];
}

function buildOpenAiImageInput(
  body: AnalyzeEmergencyBody,
): Array<{ type: 'input_image'; image_url: string }> {
  return sanitizeImageUrls(body.image_urls).map((url) => ({
    type: 'input_image',
    image_url: url,
  }));
}

function sanitizeImageUrls(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((url): url is string => typeof url === 'string')
    .map((url) => url.trim())
    .filter((url) =>
      url.startsWith('data:image/') || url.startsWith('https://')
    )
    .slice(0, 2);
}

function hasEvidenceImages(body: AnalyzeEmergencyBody): boolean {
  return sanitizeImageUrls(body.image_urls).length > 0;
}

function withoutEvidenceImages(body: AnalyzeEmergencyBody): AnalyzeEmergencyBody {
  const copy = { ...body };
  delete copy.image_urls;
  return copy;
}

function safeParseAnalysis(
  rawText: string | null,
  description: string,
): EmergencyAnalysis {
  const fallback = buildFallbackAnalysis(description);
  if (!rawText) return fallback;

  try {
    const parsed = JSON.parse(stripCodeFence(rawText)) as Record<string, unknown>;
    return validateAnalysis(parsed, fallback);
  } catch (error) {
    console.error('[analyze-emergency] Invalid JSON from model:', rawText, error);
    return fallback;
  }
}

function validateAnalysis(
  parsed: Record<string, unknown>,
  fallback: EmergencyAnalysis,
): EmergencyAnalysis {
  const categoria = normalizeAllowedValue(parsed.categoria, ALLOWED_CATEGORIES);
  const urgencia = normalizeAllowedValue(parsed.urgencia, ALLOWED_URGENCIES);
  const tipoDanio = sanitizeText(parsed.tipo_danio);
  const resumenTecnico = sanitizeText(parsed.resumen_tecnico);
  const recomendacion = sanitizeText(parsed.recomendacion);
  const requiereGrua = parsed.requiere_grua;

  if (
    !categoria ||
    !urgencia ||
    !tipoDanio ||
    !resumenTecnico ||
    typeof requiereGrua !== 'boolean' ||
    !recomendacion
  ) {
    return fallback;
  }

  const normalized = normalizeRoleConsistency({
    categoria,
    requiere_grua: requiereGrua,
  });

  return {
    categoria: normalized.categoria,
    tipo_danio: tipoDanio,
    resumen_tecnico: resumenTecnico,
    urgencia,
    requiere_grua: normalized.requiere_grua,
    recomendacion,
  };
}

function normalizeRoleConsistency({
  categoria,
  requiere_grua,
}: {
  categoria: AllowedCategory;
  requiere_grua: boolean;
}): {
  categoria: AllowedCategory;
  requiere_grua: boolean;
} {
  if (requiere_grua) {
    return {
      categoria: 'Grúa / remolque',
      requiere_grua: true,
    };
  }

  if (categoria === 'Grúa / remolque') {
    return {
      categoria,
      requiere_grua: true,
    };
  }

  return {
    categoria,
    requiere_grua: false,
  };
}

function buildFallbackAnalysis(description: string): EmergencyAnalysis {
  const normalizedDescription = sanitizeText(description) ||
    'Problema vehicular por confirmar';
  const shortened = truncate(normalizedDescription, 110);
  return {
    categoria: 'Auxilio general',
    tipo_danio:
      `La información disponible sugiere un problema vehicular que todavía no puede asociarse con seguridad a un sistema específico. La descripción fue: "${truncate(normalizedDescription, 120)}". Es necesaria una revisión en sitio para identificar la causa y confirmar si el vehículo puede circular.`,
    resumen_tecnico:
      `Reportado por el conductor: ${shortened}. El detalle no permite aislar una causa con suficiente confianza. Confirmar condición de arranque y marcha, testigos del tablero, ruidos, olores, humo, fugas, temperatura y momento en que apareció la falla. Inspeccionar primero los sistemas relacionados con los síntomas observables y verificar si existe riesgo eléctrico, mecánico o de rodamiento. Determinar en sitio si procede reparación básica o traslado seguro.`,
    urgencia: 'media',
    requiere_grua: false,
    recomendacion:
      'Estaciona en un lugar seguro, enciende las luces de emergencia y evita seguir conduciendo si notas humo, olor a combustible, temperatura alta, pérdida de frenos o ruidos fuertes. Espera la evaluación del técnico sin manipular componentes calientes o eléctricos.',
  };
}

function extractChatCompletionsOutputText(payload: {
  choices?: Array<{
    message?: {
      content?:
        | string
        | Array<{
            type?: string;
            text?: string;
          }>;
    };
  }>;
}): string | null {
  const content = payload.choices?.[0]?.message?.content;
  if (typeof content === 'string') {
    return content;
  }

  if (Array.isArray(content)) {
    const text = content
      .map((item) => (item.type === 'text' ? item.text ?? '' : ''))
      .join('')
      .trim();
    return text || null;
  }

  return null;
}

function extractOpenAiResponsesOutputText(payload: {
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

function parseProviderError(detail: string, fallbackCode: string): {
  code: string;
  message: string;
  httpStatus: number;
} {
  try {
    const parsed = JSON.parse(detail) as {
      error?: { code?: string; message?: string };
      message?: string;
    };
    const code = parsed.error?.code ?? fallbackCode;
    const message = parsed.error?.message ?? parsed.message ??
      'Provider request failed';
    return {
      code,
      message,
      httpStatus: code === 'insufficient_quota' ? 503 : 502,
    };
  } catch {
    return {
      code: fallbackCode,
      message: detail || 'Provider request failed',
      httpStatus: 502,
    };
  }
}

function stripCodeFence(text: string): string {
  return text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
}

function normalizeAllowedValue<T extends readonly string[]>(
  value: unknown,
  allowed: T,
): T[number] | null {
  const candidate = sanitizeText(value);
  if (!candidate) return null;
  return (allowed as readonly string[]).includes(candidate)
    ? (candidate as T[number])
    : null;
}

function sanitizeText(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength - 1).trim()}…`;
}

const analysisSchema = {
  type: 'object',
  properties: {
    categoria: {
      type: 'string',
      enum: [...ALLOWED_CATEGORIES],
    },
    tipo_danio: { type: 'string' },
    resumen_tecnico: { type: 'string' },
    urgencia: {
      type: 'string',
      enum: [...ALLOWED_URGENCIES],
    },
    requiere_grua: { type: 'boolean' },
    recomendacion: { type: 'string' },
  },
  required: [
    'categoria',
    'tipo_danio',
    'resumen_tecnico',
    'urgencia',
    'requiere_grua',
    'recomendacion',
  ],
  additionalProperties: false,
} as const;

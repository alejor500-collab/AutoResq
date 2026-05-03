ALTER TABLE public.emergencias
  ADD COLUMN IF NOT EXISTS ai_emergency_type text
    CHECK (
      ai_emergency_type IS NULL
      OR ai_emergency_type IN (
        'battery', 'tire', 'fuel', 'engine', 'overheating', 'accident',
        'lockout', 'electrical', 'brakes', 'unknown', 'not_emergency'
      )
    ),
  ADD COLUMN IF NOT EXISTS ai_priority text
    CHECK (
      ai_priority IS NULL
      OR ai_priority IN ('low', 'medium', 'high', 'critical')
    ),
  ADD COLUMN IF NOT EXISTS ai_user_message text,
  ADD COLUMN IF NOT EXISTS ai_safety_recommendation text,
  ADD COLUMN IF NOT EXISTS ai_technician_summary text,
  ADD COLUMN IF NOT EXISTS ai_detected_risks text[] NOT NULL DEFAULT ARRAY['none']::text[],
  ADD COLUMN IF NOT EXISTS ai_requires_immediate_attention boolean,
  ADD COLUMN IF NOT EXISTS ai_confidence numeric(4,3)
    CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1)),
  ADD COLUMN IF NOT EXISTS ai_analysis_status text NOT NULL DEFAULT 'pending'
    CHECK (ai_analysis_status IN ('pending', 'completed', 'failed')),
  ADD COLUMN IF NOT EXISTS ai_analyzed_at timestamp with time zone;

CREATE INDEX IF NOT EXISTS idx_emergencias_ai_emergency_type
  ON public.emergencias(ai_emergency_type);

CREATE INDEX IF NOT EXISTS idx_emergencias_ai_priority
  ON public.emergencias(ai_priority);

CREATE INDEX IF NOT EXISTS idx_emergencias_ai_requires_immediate_attention
  ON public.emergencias(ai_requires_immediate_attention)
  WHERE ai_requires_immediate_attention = true;

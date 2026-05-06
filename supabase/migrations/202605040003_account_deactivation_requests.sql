-- Admin-controlled account deactivation and user reactivation requests.

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS account_disabled_reason text,
  ADD COLUMN IF NOT EXISTS account_disabled_at timestamptz,
  ADD COLUMN IF NOT EXISTS account_disabled_by uuid REFERENCES public.usuarios(id);

CREATE TABLE IF NOT EXISTS public.account_reactivation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  reason text NOT NULL,
  evidence_url text,
  evidence_file_name text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  admin_response text,
  reviewed_by uuid REFERENCES public.usuarios(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_reactivation_requests_user
  ON public.account_reactivation_requests(user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS account_reactivation_one_pending_per_user
  ON public.account_reactivation_requests(user_id)
  WHERE status = 'pending';

ALTER TABLE public.account_reactivation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "account_reactivation_select_own_or_admin"
  ON public.account_reactivation_requests;
CREATE POLICY "account_reactivation_select_own_or_admin"
  ON public.account_reactivation_requests
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.get_rol_usuario(auth.uid()) = 'administrador'
  );

DROP POLICY IF EXISTS "account_reactivation_insert_own_disabled"
  ON public.account_reactivation_requests;
CREATE POLICY "account_reactivation_insert_own_disabled"
  ON public.account_reactivation_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND status = 'pending'
    AND EXISTS (
      SELECT 1
      FROM public.usuarios u
      WHERE u.id = auth.uid()
        AND u.activo = false
    )
  );

DROP POLICY IF EXISTS "account_reactivation_update_own_pending"
  ON public.account_reactivation_requests;
CREATE POLICY "account_reactivation_update_own_pending"
  ON public.account_reactivation_requests
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status = 'pending')
  WITH CHECK (
    user_id = auth.uid()
    AND status IN ('pending', 'cancelled')
    AND reviewed_by IS NULL
    AND reviewed_at IS NULL
  );

DROP POLICY IF EXISTS "account_reactivation_admin_update"
  ON public.account_reactivation_requests;
CREATE POLICY "account_reactivation_admin_update"
  ON public.account_reactivation_requests
  FOR UPDATE TO authenticated
  USING (public.get_rol_usuario(auth.uid()) = 'administrador')
  WITH CHECK (public.get_rol_usuario(auth.uid()) = 'administrador');

DROP POLICY IF EXISTS "usuarios_select_own" ON public.usuarios;
DROP POLICY IF EXISTS "usuarios_select_own_or_admin" ON public.usuarios;
CREATE POLICY "usuarios_select_own_or_admin" ON public.usuarios
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR public.get_rol_usuario(auth.uid()) = 'administrador'
  );

DROP POLICY IF EXISTS "usuarios_admin_update" ON public.usuarios;
CREATE POLICY "usuarios_admin_update" ON public.usuarios
  FOR UPDATE TO authenticated
  USING (public.get_rol_usuario(auth.uid()) = 'administrador')
  WITH CHECK (public.get_rol_usuario(auth.uid()) = 'administrador');

CREATE OR REPLACE FUNCTION public.prevent_non_admin_account_field_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF public.get_rol_usuario(auth.uid()) = 'administrador' THEN
    RETURN NEW;
  END IF;

  IF NEW.id = auth.uid() THEN
    IF NEW.rol IS DISTINCT FROM OLD.rol
      OR NEW.activo IS DISTINCT FROM OLD.activo
      OR NEW.account_disabled_reason IS DISTINCT FROM OLD.account_disabled_reason
      OR NEW.account_disabled_at IS DISTINCT FROM OLD.account_disabled_at
      OR NEW.account_disabled_by IS DISTINCT FROM OLD.account_disabled_by THEN
      RAISE EXCEPTION 'No puedes modificar campos administrativos de la cuenta.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_non_admin_account_field_update
  ON public.usuarios;
CREATE TRIGGER prevent_non_admin_account_field_update
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_non_admin_account_field_update();

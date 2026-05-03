-- Fix RLS recursion on public.usuarios.
-- Policies on usuarios call get_rol_usuario(); the function must bypass RLS
-- while reading usuarios or PostgreSQL can recurse through the same policies.

CREATE OR REPLACE FUNCTION public.get_rol_usuario(user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
  SELECT rol FROM public.usuarios WHERE id = user_id;
$$;

REVOKE ALL ON FUNCTION public.get_rol_usuario(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_rol_usuario(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_rol_usuario(uuid) TO service_role;

DROP POLICY IF EXISTS "usuarios_insert_own" ON public.usuarios;
CREATE POLICY "usuarios_insert_own" ON public.usuarios
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "usuarios_update_own" ON public.usuarios;
CREATE POLICY "usuarios_update_own" ON public.usuarios
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

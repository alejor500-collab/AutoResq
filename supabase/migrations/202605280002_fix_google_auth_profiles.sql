-- Google OAuth sends full_name/name and avatar_url/picture, not the
-- app-specific nombre key used by email registration.

CREATE OR REPLACE FUNCTION public.crear_perfil_usuario()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.usuarios (
        id,
        nombre,
        email,
        telefono,
        rol,
        avatar_url
    )
    VALUES (
        NEW.id,
        COALESCE(
            NULLIF(TRIM(NEW.raw_user_meta_data->>'nombre'), ''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
            split_part(NEW.email, '@', 1)
        ),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'telefono', ''),
        CASE
            WHEN NEW.raw_user_meta_data->>'rol' IN ('conductor', 'tecnico', 'administrador')
                THEN NEW.raw_user_meta_data->>'rol'
            ELSE 'conductor'
        END,
        COALESCE(
            NULLIF(TRIM(NEW.raw_user_meta_data->>'avatar_url'), ''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'picture'), '')
        )
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        nombre = CASE
            WHEN public.usuarios.nombre IS NULL
              OR TRIM(public.usuarios.nombre) = ''
              OR public.usuarios.nombre = split_part(EXCLUDED.email, '@', 1)
                THEN EXCLUDED.nombre
            ELSE public.usuarios.nombre
        END,
        avatar_url = COALESCE(public.usuarios.avatar_url, EXCLUDED.avatar_url);
    RETURN NEW;
END;
$$;

UPDATE public.usuarios u
SET
    nombre = COALESCE(
        NULLIF(TRIM(au.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(au.raw_user_meta_data->>'name'), ''),
        u.nombre
    ),
    avatar_url = COALESCE(
        u.avatar_url,
        NULLIF(TRIM(au.raw_user_meta_data->>'avatar_url'), ''),
        NULLIF(TRIM(au.raw_user_meta_data->>'picture'), '')
    )
FROM auth.users au
WHERE au.id = u.id
  AND au.raw_app_meta_data->>'provider' = 'google'
  AND (
      (
        COALESCE(NULLIF(TRIM(au.raw_user_meta_data->>'full_name'), ''),
                 NULLIF(TRIM(au.raw_user_meta_data->>'name'), '')) IS NOT NULL
        AND (
          u.nombre IS NULL
          OR TRIM(u.nombre) = ''
          OR u.nombre = split_part(au.email, '@', 1)
        )
      )
      OR (
        u.avatar_url IS NULL
        AND COALESCE(NULLIF(TRIM(au.raw_user_meta_data->>'avatar_url'), ''),
                     NULLIF(TRIM(au.raw_user_meta_data->>'picture'), '')) IS NOT NULL
      )
  );

UPDATE public.usuarios u
SET rol = 'conductor'
FROM public.tecnicos t
WHERE t.usuario_id = u.id
  AND u.rol = 'tecnico'
  AND t.estado_verificacion IN ('pendiente', 'rechazado');

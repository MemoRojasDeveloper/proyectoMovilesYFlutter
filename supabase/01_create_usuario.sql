-- =====================================================================
-- Tabla `usuario` (módulo de autenticación)
-- =====================================================================
--  Esta migración añade la tabla de autenticación al esquema del banco.
--  NO toca ninguna tabla existente.
--
--  Ejecutar en el SQL Editor de Supabase, sobre la BD `banco_santander`.
--
--  IMPORTANTE:
--    - Los clientes se crean solos desde el frontend vía POST /api/auth/register
--      (el backend hace INSERT transaccional en cliente + usuario).
--    - Los empleados / administradores se crean MANUALMENTE desde Supabase
--      (SQL Editor o panel Auth). Este script NO crea ningún empleado.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.usuario (
    id_usuario       SERIAL PRIMARY KEY,
    email            VARCHAR(120) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    rol              VARCHAR(20)  NOT NULL DEFAULT 'cliente',
    curp             VARCHAR(18)  UNIQUE,
    activo           BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT usuario_rol_check
        CHECK (rol IN ('cliente', 'empleado')),

    CONSTRAINT usuario_curp_fk
        FOREIGN KEY (curp)
        REFERENCES public.cliente(curp)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_usuario_email_lower
    ON public.usuario (LOWER(email));

-- Verificación rápida (debería devolver 0 filas hasta que alguien se
-- registre por primera vez):
-- SELECT id_usuario, email, rol, activo FROM public.usuario;

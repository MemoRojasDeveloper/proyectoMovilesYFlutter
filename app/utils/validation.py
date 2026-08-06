"""Regex compartidas para validación de formularios.

Estas constantes son la FUENTE DE VERDAD de las validaciones. El backend
y el cliente Flutter deben usar exactamente las mismas reglas para
mantener la UX consistente.

Documentación de cada regla:
"""

from __future__ import annotations

import re

# ─────────────────────────────────────────────────────────────────────
# Reglas de validación
# ─────────────────────────────────────────────────────────────────────
#
# - CURP: 18 caracteres, formato oficial mexicano
#   4 letras + 6 dígitos (YYMMDD) + 1 letra (sexo) + 1 letra (estado) +
#   3 letras (consonantes internas) + 1 carácter alfanumérico (homoclave).
#
# - Email: validación pragmática (RFC 5322 simplificado).
#
# - Teléfono mexicano: 10 dígitos, lada + número. Acepta opcionalmente
#   prefijo +52 y separadores (espacios/guiones) — se limpian después.
#
# - Contraseña: mínimo 8 caracteres, al menos 1 minúscula, 1 mayúscula
#   y 1 dígito. Permite símbolos. NO exige carácter especial.
#
# - Nombre / apellido: letras Unicode (incluye acentos y ñ), espacios,
#   apóstrofes y guiones. Mínimo 2 caracteres.
# ─────────────────────────────────────────────────────────────────────

CURP_REGEX = re.compile(
    r"^[A-Z]{4}"               # letras iniciales (apellido pat + mat + nombre)
    r"\d{6}"                   # fecha YYMMDD
    r"[HM]"                    # sexo (H/M)
    r"[A-Z]{2}"                # estado (2 letras)
    r"[BCDFGHJKLMNPQRSTVWXYZ]{3}"  # consonantes internas (sin A,E,I,O,U)
    r"[A-Z0-9]"                # homoclave alfanumérica
    r"\d$"                     # dígito verificador
)


EMAIL_REGEX = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")

TELEFONO_REGEX = re.compile(r"^(\+?52\s?)?\d{10}$")

PASSWORD_REGEX = re.compile(r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$")

# Nombre / apellido: letras Unicode (incluye acentos y ñ), espacios,
# apóstrofes y guiones. Mínimo 2 caracteres.
NOMBRE_REGEX = re.compile(
    r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü][A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]{1,99}$"
)


# ─────────────────────────────────────────────────────────────────────
# Funciones utilitarias
# ─────────────────────────────────────────────────────────────────────
def validar_curp(curp: str | None) -> tuple[bool, str | None]:
    """Devuelve (es_valido, mensaje_de_error)."""
    if not curp or not isinstance(curp, str):
        return False, "CURP es obligatorio"
    curp = curp.strip().upper()
    if len(curp) != 18:
        return False, "CURP debe tener 18 caracteres"
    if not CURP_REGEX.match(curp):
        return False, "CURP tiene un formato inválido"
    return True, None


def validar_email(email: str | None) -> tuple[bool, str | None]:
    if not email:
        return False, "Email es obligatorio"
    if len(email) > 120:
        return False, "Email demasiado largo"
    if not EMAIL_REGEX.match(email):
        return False, "Email tiene un formato inválido"
    return True, None


def validar_password(password: str | None) -> tuple[bool, str | None]:
    if not password:
        return False, "Contraseña es obligatoria"
    if not PASSWORD_REGEX.match(password):
        return False, (
            "La contraseña debe tener mínimo 8 caracteres, "
            "incluyendo al menos una mayúscula, una minúscula y un dígito"
        )
    return True, None


def validar_nombre(campo: str, valor: str | None) -> tuple[bool, str | None]:
    if not valor:
        return False, f"{campo} es obligatorio"
    if not NOMBRE_REGEX.match(valor.strip()):
        return False, f"{campo} contiene caracteres no permitidos"
    return True, None


def normalizar_telefono(telefono: str | None) -> str | None:
    """Quita espacios y guiones para guardar limpio. Valida 10 dígitos."""
    if telefono is None:
        return None
    limpio = re.sub(r"[\s-]", "", telefono)
    if not TELEFONO_REGEX.match(limpio):
        return None  # señal de inválido
    return limpio

"""Decorador de autenticación y helpers de JWT."""

from functools import wraps

from flask import jsonify
from flask_jwt_extended import (
    get_jwt,
    verify_jwt_in_request,
)


def require_auth(roles: tuple[str, ...] | None = None):
    """Decorador que valida el JWT y, opcionalmente, el rol.

    Uso:
        @bp.route("/x")
        @require_auth()                          # solo autenticado
        @require_auth(("cliente",))              # solo cliente
        @require_auth(("cliente", "empleado"))   # ambos
    """

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            try:
                verify_jwt_in_request()
            except Exception as exc:
                return (
                    jsonify({"error": f"No autenticado: {exc!s}"}),
                    401,
                )

            if roles is not None:
                claims = get_jwt()
                rol_usuario = claims.get("rol")
                if rol_usuario not in roles:
                    return (
                        jsonify(
                            {
                                "error": (
                                    f"Acceso denegado: rol requerido "
                                    f"{list(roles)}, tienes {rol_usuario!r}"
                                )
                            }
                        ),
                        403,
                    )

            return fn(*args, **kwargs)

        return wrapper

    return decorator

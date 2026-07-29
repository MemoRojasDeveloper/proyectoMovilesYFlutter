"""Toda la lógica vive en el paquete ``app/`` (factory pattern + Blueprints).
Esto solo:
  1. Construye la app con la factory.
  2. La expone a nivel módulo para que ``flask run`` la encuentre.
  3. Levanta el servidor de desarrollo con ``python app.py``.
"""
from __future__ import annotations

from app import create_app

app = create_app()


if __name__ == "__main__":
    app.run(debug=True, port=5000)

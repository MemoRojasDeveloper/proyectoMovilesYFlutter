"""Toda la lógica vive en el paquete ``app/`` (factory pattern + Blueprints).
Esto solo:
  1. Construye la app con la factory.
  2. La expone a nivel módulo para que ``flask run`` o gunicorn la encuentren.
  3. En desarrollo: ``python app.py`` levanta el server de Flask.
  4. En producción: ejecutar ``gunicorn`` (ver README).
"""
from __future__ import annotations

from app import create_app

app = create_app()


if __name__ == "__main__":
    # Solo desarrollo local: escucha en 127.0.0.1:5000
    app.run(debug=True, host="127.0.0.1", port=5000)
    # Producción (Linux): usar gunicorn en su lugar:
    #   gunicorn -w 2 -b 0.0.0.0:5000 'app:app'
    # Si Nginx hace de reverse proxy y termina TLS, gunicorn escucha
    # solo en 127.0.0.1:5000 (lo recomendado) detrás del proxy.

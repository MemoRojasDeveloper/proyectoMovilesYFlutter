"""Extensiones compartidas de Flask para evitar ciclos de import."""
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

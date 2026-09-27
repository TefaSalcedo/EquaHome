"""Fábrica del almacenamiento de imágenes (local por ahora, S3 en prod)."""

from functools import lru_cache

from app.services.storage.base import ImageStorage
from app.services.storage.local import LocalImageStorage


@lru_cache
def get_storage() -> ImageStorage:
    return LocalImageStorage()

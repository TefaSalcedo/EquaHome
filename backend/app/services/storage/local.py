"""Almacenamiento local de imágenes (desarrollo). En prod va S3-compatible."""

import uuid
from pathlib import Path

from app.core.config import settings
from app.services.storage.base import ImageStorage

_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}


class LocalImageStorage(ImageStorage):
    def __init__(self, root: str | None = None):
        self.root = Path(root or settings.storage_dir)
        self.root.mkdir(parents=True, exist_ok=True)

    def save(self, data: bytes, content_type: str) -> str:
        ext = _EXTENSIONS.get(content_type, ".bin")
        key = f"{uuid.uuid4()}{ext}"
        (self.root / key).write_bytes(data)
        return key

    def load(self, storage_key: str) -> bytes:
        return (self.root / storage_key).read_bytes()

    def get_url(self, storage_key: str) -> str:
        return f"/api/v1/photos/file/{storage_key}"

    def delete(self, storage_key: str) -> None:
        (self.root / storage_key).unlink(missing_ok=True)

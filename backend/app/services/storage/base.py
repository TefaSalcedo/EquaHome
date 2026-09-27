"""Image storage contract.

Keeps binary blobs out of PostgreSQL; implementations: local filesystem
(dev) and S3-compatible object storage (prod).
"""

from abc import ABC, abstractmethod


class ImageStorage(ABC):
    @abstractmethod
    def save(self, data: bytes, content_type: str) -> str:
        """Store bytes and return the storage key."""

    @abstractmethod
    def get_url(self, storage_key: str) -> str:
        """Return a URL (signed when needed) to fetch the object."""

    @abstractmethod
    def delete(self, storage_key: str) -> None:
        """Remove the object."""

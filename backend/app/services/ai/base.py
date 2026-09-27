"""AI provider contract.

Implementations (e.g. GrokProvider) plug in here so the provider can be
swapped without touching domain services. Phase 06+ wires real providers;
the mock implementation keeps the app fully functional without AI.
"""

from abc import ABC, abstractmethod
from typing import Any


class AIService(ABC):
    @abstractmethod
    def analyze_room_photo(self, image_bytes: bytes) -> dict[str, Any]:
        """Detect furniture/objects in a room photo. Returns a draft detection the user must confirm."""

    @abstractmethod
    def analyze_daily_photo(self, image_bytes: bytes) -> dict[str, Any]:
        """Assess the general state of a room. Orientative — never assigns blame."""

    @abstractmethod
    def interpret_instruction(self, text: str, context: dict[str, Any]) -> dict[str, Any]:
        """Turn a free-text instruction into a proposed plan change for user confirmation."""

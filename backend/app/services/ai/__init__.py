"""Fábrica del proveedor de IA.

EQUAHOME_AI_PROVIDER=mock (default) usa detecciones de ejemplo; "grok" se
conecta en la fase 07. El resto de la app solo conoce la interfaz AIService.
"""

from app.core.config import settings
from app.services.ai.base import AIService
from app.services.ai.mock import MockAIService


def get_ai_service() -> AIService:
    if settings.ai_provider == "mock":
        return MockAIService()
    raise NotImplementedError(
        f"Proveedor de IA no configurado: {settings.ai_provider!r}"
    )

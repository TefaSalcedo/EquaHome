"""Proveedor de IA de ejemplo: respuestas deterministas.

Mantiene la app completamente funcional sin IA real; toda detección es un
borrador que la persona confirma o corrige.
"""

from typing import Any

from app.services.ai.base import AIService


class MockAIService(AIService):
    provider = "mock"
    model = "mock-v1"

    def analyze_room_photo(self, image_bytes: bytes) -> dict[str, Any]:
        return {
            "summary": (
                "Detección de ejemplo — revisa y ajusta los objetos antes de "
                "guardarlos en la habitación."
            ),
            "objects": [
                {"name": "Cama", "quantity": 1},
                {"name": "Mesita de noche", "quantity": 1},
                {"name": "Lámpara", "quantity": 1},
            ],
        }

    def analyze_daily_photo(self, image_bytes: bytes) -> dict[str, Any]:
        return {
            "summary": (
                "Evaluación orientativa de ejemplo: la habitación se ve "
                "razonablemente ordenada. Tú decides si está bien."
            ),
            "score": 0.7,
        }

    def interpret_instruction(
        self, text: str, context: dict[str, Any]
    ) -> dict[str, Any]:
        """Reglas de ejemplo: devuelve acciones que /assistant/apply ejecuta."""
        lower = text.lower()
        if any(k in lower for k in ("no estoy", "no puedo", "no voy a estar")):
            return {
                "summary": (
                    "Entendido. Propongo liberar las tareas que elegiste hoy "
                    "para que cualquier otra persona pueda tomarlas."
                ),
                "actions": [{"type": "release_my_tasks"}],
            }
        if any(k in lower for k in ("pasar", "posponer", "para mañana")):
            return {
                "summary": "Propongo mover tus tareas elegidas de hoy a mañana.",
                "actions": [{"type": "postpone_my_tasks"}],
            }
        if any(k in lower for k in ("agrega", "añade", "crea")):
            return {
                "summary": "Propongo crear esta tarea puntual para hoy.",
                "actions": [
                    {
                        "type": "create_task",
                        "title": text.strip()[:60],
                        "estimated_minutes": 20,
                    }
                ],
            }
        return {
            "summary": (
                f"Propuesta de ejemplo para «{text}». Con el proveedor real "
                "aquí iría la reorganización sugerida."
            ),
            "actions": [],
        }

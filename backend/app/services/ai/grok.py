"""GrokService (xAI) — ESQUELETO para conectar en fase 07.

La API de xAI es compatible con el SDK de OpenAI:
  - base_url: https://api.x.ai/v1  (config: EQUAHOME_GROK_BASE_URL)
  - api_key:  EQUAHOME_GROK_API_KEY
  - modelo:   EQUAHOME_GROK_MODEL  (elige un modelo con visión)

Para implementar cada método llama POST {base_url}/chat/completions con
messages estilo OpenAI; para fotos incluye la imagen como content
{"type": "image_url", "image_url": {"url": "data:<mime>;base64,<...>"}}.

Contrato que espera el resto de la app (ver AIService):
  analyze_room_photo   → {"summary": str, "objects": [{"name": str, "quantity": int}]}
  analyze_daily_photo  → {"summary": str, "score": float}  # orientativo, sin culpar
  interpret_instruction→ {"summary": str, "actions": [{"type": str, ...}]}
    Tipos de acción que /assistant/apply sabe ejecutar:
      - {"type": "release_my_tasks"}   libera mis tareas elegidas de hoy
      - {"type": "postpone_my_tasks"}  mueve mis tareas elegidas a mañana
      - {"type": "create_task", "title": str, "estimated_minutes": int}

Todo lo que devuelva la IA es un BORRADOR: la persona lo revisa y confirma.
"""

import base64
from typing import Any

from app.core.config import settings
from app.services.ai.base import AIService


class GrokService(AIService):
    provider = "grok"

    def __init__(self) -> None:
        self.api_key = settings.grok_api_key
        self.model = settings.grok_model
        self.base_url = settings.grok_base_url.rstrip("/")

    def _data_url(self, image_bytes: bytes, content_type: str = "image/jpeg") -> str:
        return f"data:{content_type};base64,{base64.b64encode(image_bytes).decode()}"

    def _chat(self, messages: list[dict[str, Any]]) -> dict[str, Any]:
        """TODO (Estefania): POST /chat/completions y parsear JSON de respuesta.

        Esbozo:
            resp = httpx.post(
                f"{self.base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model,
                    "messages": messages,
                    "response_format": {"type": "json_object"},
                },
                timeout=30,
            )
            resp.raise_for_status()
            return json.loads(resp.json()["choices"][0]["message"]["content"])
        """
        raise NotImplementedError(
            "GrokService._chat pendiente — completa la llamada a la API de xAI"
        )

    def analyze_room_photo(self, image_bytes: bytes) -> dict[str, Any]:
        # TODO: prompt con la imagen pidiendo {"summary","objects":[...]}.
        return self._chat(
            [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "Detecta los objetos visibles de esta habitación. "
                                'Responde JSON {"summary": str, "objects": '
                                '[{"name": str, "quantity": int}]}.'
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": self._data_url(image_bytes)},
                        },
                    ],
                }
            ]
        )

    def analyze_daily_photo(self, image_bytes: bytes) -> dict[str, Any]:
        # TODO: prompt orientativo — evaluar el estado general, nunca culpar.
        return self._chat(
            [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "Evalúa de forma orientativa el orden/limpieza de "
                                "esta habitación. Responde JSON "
                                '{"summary": str, "score": float 0..1}.'
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": self._data_url(image_bytes)},
                        },
                    ],
                }
            ]
        )

    def interpret_instruction(
        self, text: str, context: dict[str, Any]
    ) -> dict[str, Any]:
        # TODO: prompt con `text` + context (tareas/miembros) → propuesta JSON.
        return self._chat(
            [
                {
                    "role": "system",
                    "content": (
                        "Eres el asistente de EquaHome. La app propone y "
                        "reorganiza; nunca impone. Devuelve JSON "
                        '{"summary": str, "actions": [...]}.'
                    ),
                },
                {
                    "role": "user",
                    "content": f"Contexto: {context}\nInstrucción: {text}",
                },
            ]
        )

"""GroqService — proveedor real vía la API OpenAI-compatible de Groq.

Config (.env):
    EQUAHOME_AI_PROVIDER=groq
    EQUAHOME_GROQ_API_KEY=gsk_...           https://console.groq.com/keys
    EQUAHOME_GROQ_MODEL=llama-3.3-70b-versatile        # texto (asistente)
    EQUAHOME_GROQ_VISION_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
    EQUAHOME_GROQ_BASE_URL=https://api.groq.com/openai/v1

Contrato que espera el resto de la app (ver AIService):
    analyze_room_photo   → {"summary": str, "objects": [{"name": str, "quantity": int}]}
    analyze_daily_photo  → {"summary": str, "score": float 0..1}  # orientativo
    interpret_instruction→ {"summary": str, "actions": [{"type": str, ...}]}
      Tipos que /assistant/apply sabe ejecutar:
        {"type": "release_my_tasks"}, {"type": "postpone_my_tasks"},
        {"type": "create_task", "title": str, "estimated_minutes": int}

Todo lo que devuelve la IA es un BORRADOR: la persona lo revisa y confirma.
"""

import base64
import json
from typing import Any

import httpx

from app.core.config import settings
from app.services.ai.base import AIService

_INSTRUCTION_SYSTEM = """\
Eres el asistente de EquaHome, una app que reparte las tareas del hogar \
de forma justa. La app PROPONE y reorganiza; NUNCA impone — cada propuesta \
la confirma la persona antes de aplicarse.

Recibirás el contexto del día (tareas abiertas, cuáles elegí yo) y una \
instrucción en texto libre. Responde SOLO JSON válido:
{"summary": "qué propones, en español, una línea", "actions": [...]}

Acciones permitidas (cualquier otra será ignorada):
- {"type": "release_my_tasks"} — libero las tareas que elegí hoy para que \
otra persona las tome (ej. "mañana no estoy", "no puedo hoy").
- {"type": "postpone_my_tasks"} — muevo mis tareas elegidas a mañana \
(ej. "paso esto para mañana").
- {"type": "create_task", "title": "...", "estimated_minutes": int} — \
crear una tarea puntual para hoy (ej. "agrega regar las plantas"). \
El title debe ser SOLO el nombre de la tarea, sin el verbo "agrega/crea".

Si la instrucción no pide ningún cambio concreto, devuelve \
{"summary": "...", "actions": []}.
"""


class GroqService(AIService):
    provider = "groq"

    def __init__(self) -> None:
        if not settings.groq_api_key:
            raise RuntimeError(
                "Falta EQUAHOME_GROQ_API_KEY — crea una en "
                "https://console.groq.com/keys"
            )
        self.api_key = settings.groq_api_key
        self.model = settings.groq_model
        self.vision_model = settings.groq_vision_model
        self.base_url = settings.groq_base_url.rstrip("/")

    @staticmethod
    def _data_url(image_bytes: bytes, content_type: str = "image/jpeg") -> str:
        return f"data:{content_type};base64,{base64.b64encode(image_bytes).decode()}"

    def _chat(
        self,
        messages: list[dict[str, Any]],
        *,
        model: str | None = None,
    ) -> dict[str, Any]:
        resp = httpx.post(
            f"{self.base_url}/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}"},
            json={
                "model": model or self.model,
                "messages": messages,
                "response_format": {"type": "json_object"},
                "temperature": 0.2,
            },
            timeout=60,
        )
        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError as exc:
            try:
                detail = exc.response.json().get("error", {}).get("message", "")
            except ValueError:
                detail = exc.response.text[:200]
            raise RuntimeError(
                f"Groq respondió {exc.response.status_code}: {detail}"
            ) from exc
        content = resp.json()["choices"][0]["message"]["content"]
        return json.loads(content)

    def analyze_room_photo(self, image_bytes: bytes) -> dict[str, Any]:
        return self._chat(
            [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "Detecta los objetos visibles en esta foto de una "
                                "habitación (muebles, electrodomésticos y objetos "
                                "relevantes para las tareas de limpieza). Responde "
                                'SOLO JSON {"summary": str, "objects": '
                                '[{"name": str, "quantity": int}]} en español.'
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": self._data_url(image_bytes)},
                        },
                    ],
                }
            ],
            model=self.vision_model,
        )

    def analyze_daily_photo(self, image_bytes: bytes) -> dict[str, Any]:
        return self._chat(
            [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "Evalúa de forma ORIENTATIVA el estado de "
                                "orden/limpieza de esta habitación, como quien da "
                                "una mirada general al final del día. Sé "
                                "constructivo, nunca culpes a nadie. Responde SOLO "
                                'JSON {"summary": str, "score": float entre 0 y 1} '
                                "en español."
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": self._data_url(image_bytes)},
                        },
                    ],
                }
            ],
            model=self.vision_model,
        )

    def interpret_instruction(
        self, text: str, context: dict[str, Any]
    ) -> dict[str, Any]:
        return self._chat(
            [
                {"role": "system", "content": _INSTRUCTION_SYSTEM},
                {
                    "role": "user",
                    "content": (
                        f"Contexto: {json.dumps(context, ensure_ascii=False)}\n"
                        f"Instrucción: {text}"
                    ),
                },
            ],
        )

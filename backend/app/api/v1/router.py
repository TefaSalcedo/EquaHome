from fastapi import APIRouter

from app.api.v1 import (
    auth,
    households,
    members,
    photos,
    rooms,
    task_templates,
    tasks,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(households.router)
api_router.include_router(members.router)
api_router.include_router(rooms.router)
api_router.include_router(task_templates.router)
api_router.include_router(tasks.router)
api_router.include_router(photos.router)

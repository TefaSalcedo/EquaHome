import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember
from app.models.photo import AIAnalysis, AIStatus, Photo, PhotoPurpose
from app.models.room import ObjectSource, Room, RoomObject
from app.models.user import User
from app.schemas.photo import AnalysisOut, ConfirmIn, DetectedObjectIn, PhotoOut
from app.services.ai import get_ai_service
from app.services.storage import get_storage

router = APIRouter(tags=["photos"])

_MAX_BYTES = 10 * 1024 * 1024
_ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


def _photo_out(photo: Photo) -> PhotoOut:
    storage = get_storage()
    analysis = None
    if photo.analysis is not None:
        analysis = AnalysisOut(
            id=photo.analysis.id,
            provider=photo.analysis.provider,
            model=photo.analysis.model,
            summary=photo.analysis.summary,
            objects=[
                DetectedObjectIn(**o)
                for o in photo.analysis.raw_json.get("objects", [])
            ],
            confirmed_by_user=photo.analysis.confirmed_by_user,
        )
    return PhotoOut(
        id=photo.id,
        room_id=photo.room_id,
        room_name=photo.room.name if photo.room else None,
        purpose=photo.purpose,
        ai_status=photo.ai_status,
        uploaded_at=photo.uploaded_at,
        file_url=storage.get_url(photo.storage_key),
        analysis=analysis,
    )


def _require_photo(photo_id: uuid.UUID, user: User, db: Session) -> Photo:
    photo = db.get(Photo, photo_id)
    if photo is None:
        raise HTTPException(404, "Foto no encontrada")
    member = (
        db.query(HouseholdMember.id)
        .filter(
            HouseholdMember.household_id == photo.household_id,
            HouseholdMember.user_id == user.id,
        )
        .first()
    )
    if member is None:
        raise HTTPException(403, "No eres miembro de este hogar")
    return photo


@router.post(
    "/households/{household_id}/photos",
    response_model=PhotoOut,
    status_code=201,
)
def upload_photo(
    file: UploadFile = File(...),
    purpose: PhotoPurpose = Form(default=PhotoPurpose.room_scan),
    room_id: uuid.UUID | None = Form(default=None),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    if file.content_type not in _ALLOWED_TYPES:
        raise HTTPException(415, "Formato no soportado: usa JPG, PNG o WebP")
    if room_id is not None:
        room = db.get(Room, room_id)
        if room is None or room.household_id != membership.household_id:
            raise HTTPException(422, "La habitación no pertenece a este hogar")
    data = file.file.read(_MAX_BYTES + 1)
    if len(data) > _MAX_BYTES:
        raise HTTPException(413, "La foto supera el límite de 10 MB")
    key = get_storage().save(data, file.content_type)
    photo = Photo(
        household_id=membership.household_id,
        room_id=room_id,
        member_id=membership.id,
        storage_key=key,
        content_type=file.content_type,
        purpose=purpose,
    )
    db.add(photo)
    db.commit()
    return _photo_out(photo)


@router.get("/households/{household_id}/photos", response_model=list[PhotoOut])
def list_photos(
    room_id: uuid.UUID | None = Query(default=None),
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    query = db.query(Photo).filter(Photo.household_id == membership.household_id)
    if room_id is not None:
        query = query.filter(Photo.room_id == room_id)
    return [_photo_out(p) for p in query.order_by(Photo.uploaded_at.desc()).all()]


@router.get("/photos/{photo_id}", response_model=PhotoOut)
def get_photo(
    photo_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _photo_out(_require_photo(photo_id, user, db))


@router.get("/photos/{photo_id}/file")
def photo_file(
    photo_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    photo = _require_photo(photo_id, user, db)
    return Response(
        content=get_storage().load(photo.storage_key),
        media_type=photo.content_type,
    )


@router.delete("/photos/{photo_id}", status_code=204)
def delete_photo(
    photo_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    photo = _require_photo(photo_id, user, db)
    get_storage().delete(photo.storage_key)
    db.delete(photo)
    db.commit()


@router.post("/photos/{photo_id}/analyze", response_model=PhotoOut)
def analyze_photo(
    photo_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    photo = _require_photo(photo_id, user, db)
    ai = get_ai_service()
    data = get_storage().load(photo.storage_key)
    try:
        if photo.purpose == PhotoPurpose.daily_check:
            result = ai.analyze_daily_photo(data)
        else:
            result = ai.analyze_room_photo(data)
    except NotImplementedError as exc:
        raise HTTPException(503, "El proveedor de IA no está configurado") from exc
    if photo.analysis is not None:
        db.delete(photo.analysis)
        db.flush()
    db.add(
        AIAnalysis(
            photo=photo,
            provider=ai.provider,
            model=ai.model,
            summary=result.get("summary", ""),
            raw_json=result,
        )
    )
    photo.ai_status = AIStatus.done
    db.commit()
    return _photo_out(photo)


@router.patch("/analyses/{analysis_id}/confirm", response_model=PhotoOut)
def confirm_analysis(
    analysis_id: uuid.UUID,
    body: ConfirmIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    analysis = db.get(AIAnalysis, analysis_id)
    if analysis is None:
        raise HTTPException(404, "Análisis no encontrado")
    photo = _require_photo(analysis.photo_id, user, db)
    if photo.room_id is None:
        raise HTTPException(
            422, "La foto no está ligada a una habitación"
        )
    # Lo que la persona corrige reemplaza el borrador de la IA.
    analysis.raw_json["objects"] = [o.model_dump() for o in body.objects]
    analysis.confirmed_by_user = True
    existing = {o.name.lower(): o for o in photo.room.objects}
    for obj in body.objects:
        name = obj.name.strip()
        if not name:
            continue
        match = existing.get(name.lower())
        if match is not None:
            match.quantity = obj.quantity
            match.confirmed = True
        else:
            new_obj = RoomObject(
                room_id=photo.room_id,
                name=name,
                quantity=obj.quantity,
                source=ObjectSource.ai,
                confirmed=True,
            )
            db.add(new_obj)
            existing[name.lower()] = new_obj
    db.commit()
    return _photo_out(photo)

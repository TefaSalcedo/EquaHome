import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_membership
from app.core.db import get_db
from app.models.household import HouseholdMember
from app.models.room import Room, RoomObject
from app.models.user import User
from app.schemas.room import (
    RoomCreate,
    RoomDetail,
    RoomObjectCreate,
    RoomObjectOut,
    RoomObjectUpdate,
    RoomOut,
    RoomUpdate,
)

router = APIRouter(tags=["rooms"])


def _require_room_membership(
    room_id: uuid.UUID, user: User, db: Session
) -> tuple[Room, HouseholdMember]:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(404, "Habitación no encontrada")
    membership = (
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == room.household_id,
            HouseholdMember.user_id == user.id,
        )
        .first()
    )
    if membership is None:
        raise HTTPException(403, "No eres miembro de este hogar")
    return room, membership


def _room_out(room: Room) -> RoomOut:
    return RoomOut(
        id=room.id,
        name=room.name,
        type=room.type,
        floor=room.floor,
        object_count=len(room.objects),
        created_at=room.created_at,
    )


@router.get("/households/{household_id}/rooms", response_model=list[RoomOut])
def list_rooms(
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    rooms = db.query(Room).filter(Room.household_id == membership.household_id).all()
    return [_room_out(r) for r in rooms]


@router.post(
    "/households/{household_id}/rooms",
    response_model=RoomOut,
    status_code=201,
)
def create_room(
    body: RoomCreate,
    membership: HouseholdMember = Depends(get_membership),
    db: Session = Depends(get_db),
):
    room = Room(
        household_id=membership.household_id,
        name=body.name.strip(),
        type=body.type,
        floor=body.floor,
    )
    db.add(room)
    db.commit()
    return _room_out(room)


@router.get("/rooms/{room_id}", response_model=RoomDetail)
def get_room(
    room_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room, _ = _require_room_membership(room_id, user, db)
    return RoomDetail(
        id=room.id,
        name=room.name,
        type=room.type,
        floor=room.floor,
        objects=[RoomObjectOut.model_validate(o) for o in room.objects],
    )


@router.patch("/rooms/{room_id}", response_model=RoomOut)
def update_room(
    room_id: uuid.UUID,
    body: RoomUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room, _ = _require_room_membership(room_id, user, db)
    data = body.model_dump(exclude_unset=True)
    if "name" in data:
        room.name = data["name"].strip()
    if "type" in data:
        room.type = data["type"]
    if "floor" in data:
        room.floor = data["floor"]
    db.commit()
    return _room_out(room)


@router.delete("/rooms/{room_id}", status_code=204)
def delete_room(
    room_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room, _ = _require_room_membership(room_id, user, db)
    db.delete(room)
    db.commit()


@router.post("/rooms/{room_id}/objects", response_model=RoomObjectOut, status_code=201)
def add_object(
    room_id: uuid.UUID,
    body: RoomObjectCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room, _ = _require_room_membership(room_id, user, db)
    obj = RoomObject(room_id=room.id, name=body.name.strip(), quantity=body.quantity)
    db.add(obj)
    db.commit()
    return obj


def _load_object(
    object_id: uuid.UUID, user: User, db: Session
) -> RoomObject:
    obj = db.get(RoomObject, object_id)
    if obj is None:
        raise HTTPException(404, "Objeto no encontrado")
    _require_room_membership(obj.room_id, user, db)
    return obj


@router.patch("/objects/{object_id}", response_model=RoomObjectOut)
def update_object(
    object_id: uuid.UUID,
    body: RoomObjectUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    obj = _load_object(object_id, user, db)
    data = body.model_dump(exclude_unset=True)
    if "name" in data:
        obj.name = data["name"].strip()
    if "quantity" in data:
        obj.quantity = data["quantity"]
    if "confirmed" in data:
        obj.confirmed = data["confirmed"]
    db.commit()
    return obj


@router.delete("/objects/{object_id}", status_code=204)
def delete_object(
    object_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    obj = _load_object(object_id, user, db)
    db.delete(obj)
    db.commit()

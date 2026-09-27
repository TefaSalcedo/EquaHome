"""photos ai analyses

Revision ID: d4a1f02c8e5b
Revises: bc9c61dd1887
Create Date: 2026-09-27 19:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = 'd4a1f02c8e5b'
down_revision = 'bc9c61dd1887'
branch_labels = None
depends_on = None

_photo_purpose = postgresql.ENUM(
    'room_scan', 'daily_check', name='photo_purpose', create_type=False)
_ai_status = postgresql.ENUM(
    'none', 'done', 'failed', name='ai_status', create_type=False)


def upgrade() -> None:
    bind = op.get_bind()
    _photo_purpose.create(bind, checkfirst=True)
    _ai_status.create(bind, checkfirst=True)

    op.create_table('photos',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('household_id', sa.UUID(), nullable=False),
    sa.Column('room_id', sa.UUID(), nullable=True),
    sa.Column('member_id', sa.UUID(), nullable=True),
    sa.Column('storage_key', sa.String(length=255), nullable=False),
    sa.Column('content_type', sa.String(length=64), nullable=False),
    sa.Column('purpose', _photo_purpose, nullable=False),
    sa.Column('ai_status', _ai_status, nullable=False),
    sa.Column('uploaded_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['household_id'], ['households.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['member_id'], ['household_members.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['room_id'], ['rooms.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_photos_household_id'), 'photos', ['household_id'], unique=False)
    op.create_table('ai_analyses',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('photo_id', sa.UUID(), nullable=False),
    sa.Column('provider', sa.String(length=64), nullable=False),
    sa.Column('model', sa.String(length=64), nullable=True),
    sa.Column('summary', sa.String(length=500), nullable=False),
    sa.Column('raw_json', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('confirmed_by_user', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['photo_id'], ['photos.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_ai_analyses_photo_id'), 'ai_analyses', ['photo_id'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_ai_analyses_photo_id'), table_name='ai_analyses')
    op.drop_table('ai_analyses')
    op.drop_index(op.f('ix_photos_household_id'), table_name='photos')
    op.drop_table('photos')
    bind = op.get_bind()
    _photo_purpose.drop(bind, checkfirst=True)
    _ai_status.drop(bind, checkfirst=True)

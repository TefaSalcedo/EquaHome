"""tasks assignments preferences

Revision ID: bc9c61dd1887
Revises: 011768255243
Create Date: 2026-09-27 16:49:37.684183

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = 'bc9c61dd1887'
down_revision = '011768255243'
branch_labels = None
depends_on = None

# Enum nuevos; effort y task_category ya existen de la migración anterior.
_new_enums = [
    postgresql.ENUM('pending', 'selected', 'done', 'skipped', 'carried_over',
                    name='task_status', create_type=False),
    postgresql.ENUM('template', 'extra', 'manual',
                    name='task_origin', create_type=False),
    postgresql.ENUM('like', 'dislike', 'cannot_do',
                    name='preference_kind', create_type=False),
]

_effort = postgresql.ENUM('low', 'medium', 'high', name='effort', create_type=False)
_task_category = postgresql.ENUM(
    'cleaning', 'kitchen', 'laundry', 'bathroom', 'organization', 'outdoor',
    'general', name='task_category', create_type=False)


def upgrade() -> None:
    bind = op.get_bind()
    for enum in _new_enums:
        enum.create(bind, checkfirst=True)

    op.create_table('task_preferences',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('member_id', sa.UUID(), nullable=False),
    sa.Column('kind', postgresql.ENUM('like', 'dislike', 'cannot_do', name='preference_kind', create_type=False), nullable=False),
    sa.Column('template_id', sa.UUID(), nullable=True),
    sa.Column('category', _task_category, nullable=True),
    sa.ForeignKeyConstraint(['member_id'], ['household_members.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['template_id'], ['task_templates.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_task_preferences_member_id'), 'task_preferences', ['member_id'], unique=False)
    op.create_table('tasks',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('household_id', sa.UUID(), nullable=False),
    sa.Column('template_id', sa.UUID(), nullable=True),
    sa.Column('room_id', sa.UUID(), nullable=True),
    sa.Column('title', sa.String(length=160), nullable=False),
    sa.Column('estimated_minutes', sa.Integer(), nullable=False),
    sa.Column('effort', _effort, nullable=False),
    sa.Column('category', _task_category, nullable=False),
    sa.Column('scheduled_date', sa.Date(), nullable=False),
    sa.Column('status', postgresql.ENUM('pending', 'selected', 'done', 'skipped', 'carried_over', name='task_status', create_type=False), nullable=False),
    sa.Column('origin', postgresql.ENUM('template', 'extra', 'manual', name='task_origin', create_type=False), nullable=False),
    sa.Column('carried_from_id', sa.UUID(), nullable=True),
    sa.Column('created_by_member_id', sa.UUID(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['carried_from_id'], ['tasks.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['created_by_member_id'], ['household_members.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['household_id'], ['households.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['room_id'], ['rooms.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['template_id'], ['task_templates.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_tasks_household_id'), 'tasks', ['household_id'], unique=False)
    op.create_index(op.f('ix_tasks_scheduled_date'), 'tasks', ['scheduled_date'], unique=False)
    op.create_table('task_assignments',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('task_id', sa.UUID(), nullable=False),
    sa.Column('member_id', sa.UUID(), nullable=False),
    sa.Column('selected_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['member_id'], ['household_members.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['task_id'], ['tasks.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('task_id', 'member_id', name='uq_assignment_task_member')
    )
    op.create_index(op.f('ix_task_assignments_member_id'), 'task_assignments', ['member_id'], unique=False)
    op.create_index(op.f('ix_task_assignments_task_id'), 'task_assignments', ['task_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_task_assignments_task_id'), table_name='task_assignments')
    op.drop_index(op.f('ix_task_assignments_member_id'), table_name='task_assignments')
    op.drop_table('task_assignments')
    op.drop_index(op.f('ix_tasks_scheduled_date'), table_name='tasks')
    op.drop_index(op.f('ix_tasks_household_id'), table_name='tasks')
    op.drop_table('tasks')
    op.drop_index(op.f('ix_task_preferences_member_id'), table_name='task_preferences')
    op.drop_table('task_preferences')
    for enum in _new_enums:
        enum.drop(op.get_bind(), checkfirst=True)

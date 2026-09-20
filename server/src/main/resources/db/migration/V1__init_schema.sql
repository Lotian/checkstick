CREATE TABLE game_groups (
    id UUID PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    code VARCHAR(6) NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE role_templates (
    id UUID PRIMARY KEY,
    round_mode VARCHAR(16) NOT NULL,
    role_type VARCHAR(16) NOT NULL,
    task_text TEXT NOT NULL DEFAULT '',
    reward_text TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT ux_template_mode_role UNIQUE (round_mode, role_type),
    CONSTRAINT ck_template_mode CHECK (round_mode IN ('FIVE', 'EIGHT')),
    CONSTRAINT ck_template_role CHECK (role_type IN ('GROOM', 'BRIDE', 'VILLAGER'))
);

CREATE TABLE game_rounds (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES game_groups(id),
    round_number INTEGER NOT NULL,
    round_mode VARCHAR(16) NOT NULL,
    status VARCHAR(16) NOT NULL,
    capacity INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    closed_at TIMESTAMPTZ,
    CONSTRAINT ux_round_group_number UNIQUE (group_id, round_number),
    CONSTRAINT ck_round_mode CHECK (round_mode IN ('FIVE', 'EIGHT')),
    CONSTRAINT ck_round_status CHECK (status IN ('ACTIVE', 'FULL', 'CLOSED')),
    CONSTRAINT ck_round_capacity CHECK (capacity IN (5, 8))
);

CREATE UNIQUE INDEX ux_round_current_per_group
    ON game_rounds(group_id)
    WHERE status IN ('ACTIVE', 'FULL');

CREATE INDEX ix_round_group_started ON game_rounds(group_id, started_at DESC);

CREATE TABLE draw_slots (
    id UUID PRIMARY KEY,
    round_id UUID NOT NULL REFERENCES game_rounds(id) ON DELETE CASCADE,
    slot_index INTEGER NOT NULL,
    role_type VARCHAR(16) NOT NULL,
    task_text TEXT NOT NULL DEFAULT '',
    reward_text TEXT NOT NULL DEFAULT '',
    visitor_id VARCHAR(64),
    drawn_at TIMESTAMPTZ,
    CONSTRAINT ux_slot_round_index UNIQUE (round_id, slot_index),
    CONSTRAINT ux_slot_round_visitor UNIQUE (round_id, visitor_id),
    CONSTRAINT ck_slot_role CHECK (role_type IN ('GROOM', 'BRIDE', 'VILLAGER'))
);

CREATE INDEX ix_slot_round_claimed ON draw_slots(round_id, visitor_id);


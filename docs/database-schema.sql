-- 囍签扫码抽签系统 PostgreSQL 建表及初始化脚本
-- 本脚本可以直接交给数据库管理员执行；所有时间字段保存带时区时间。
-- 与后端 Flyway 迁移 V1+V2+V3 等价（V3 起人数不再固定为 5 人局/8 人局）。

BEGIN;

CREATE TABLE game_groups (
    id UUID PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    code VARCHAR(6) NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    -- 一局的人数区间：签位数量 = max_players，抽满 min_players 后可提前封签
    min_players INTEGER NOT NULL DEFAULT 5,
    max_players INTEGER NOT NULL DEFAULT 8,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT ck_group_player_range
        CHECK (min_players >= 2 AND max_players >= min_players AND max_players <= 20)
);

COMMENT ON TABLE game_groups IS '现场组局，一组可以依次开启多轮抽签';
COMMENT ON COLUMN game_groups.code IS '玩家输入的四位数字固定组局码';
COMMENT ON COLUMN game_groups.min_players IS '本轮最低人数：抽满后可提前封签';
COMMENT ON COLUMN game_groups.max_players IS '本轮最高人数：也是签位数量，抽满自动封签';

CREATE TABLE role_templates (
    id UUID PRIMARY KEY,
    role_type VARCHAR(16) NOT NULL,
    task_text TEXT NOT NULL DEFAULT '',
    reward_text TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT ux_template_role UNIQUE (role_type),
    CONSTRAINT ck_template_role CHECK (role_type IN ('GROOM', 'BRIDE', 'VILLAGER'))
);

COMMENT ON TABLE role_templates IS '身份任务和奖励模板：每个身份一套，适用于所有人数的局';
COMMENT ON COLUMN role_templates.task_text IS '使用换行符分隔步骤，村民固定为空';

CREATE TABLE game_rounds (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES game_groups(id),
    round_number INTEGER NOT NULL,
    status VARCHAR(16) NOT NULL,
    -- 开轮时从组局配置快照下来，之后改组局设置不影响已开始的轮次
    min_players INTEGER NOT NULL,
    max_players INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    closed_at TIMESTAMPTZ,
    CONSTRAINT ux_round_group_number UNIQUE (group_id, round_number),
    CONSTRAINT ck_round_status CHECK (status IN ('ACTIVE', 'FULL', 'CLOSED')),
    CONSTRAINT ck_round_max_players CHECK (max_players >= 2 AND max_players <= 20),
    CONSTRAINT ck_round_min_players CHECK (min_players >= 2 AND min_players <= max_players)
);

COMMENT ON TABLE game_rounds IS '每次开局产生一条轮次记录，含本轮人数区间快照';

-- 同一组局只能有一个尚未关闭的轮次。
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

COMMENT ON TABLE draw_slots IS '开轮时打乱生成的身份签位，同时保存任务与奖励快照';
COMMENT ON COLUMN draw_slots.visitor_id IS '玩家浏览器 localStorage 中的匿名 UUID';

CREATE INDEX ix_slot_round_claimed ON draw_slots(round_id, visitor_id);

INSERT INTO role_templates (id, role_type, task_text, reward_text, updated_at) VALUES
('10000000-0000-0000-0000-000000000001', 'GROOM', E'找到新娘并完成合影\n向工作人员说出指定暗号', '完成任务后，凭身份卡向工作人员领取奖励', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000002', 'BRIDE', E'找到新郎并交换线索\n与新郎共同完成指定动作', '完成任务后，凭身份卡向工作人员领取奖励', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000003', 'VILLAGER', '', '凭身份卡向工作人员领取参与奖励', CURRENT_TIMESTAMP);

COMMIT;

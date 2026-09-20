-- 人数不再固定为「5 人局 / 8 人局」，改为每个组局自定义最低~最高人数。
-- 规则：签位数量 = 最高人数；抽满最低人数后工作人员可以提前封签；抽满最高人数自动封签。
--
-- 本迁移写成幂等形式（IF EXISTS / IF NOT EXISTS / DO 块），因此：
--   * 全新空库：正常执行一次即可；
--   * 已经用 docs/manual-v3-migration.sql 手工补齐过的库：再次执行全部是空操作，
--     配合 spring.flyway.baseline-version=2，Flyway 会把它记为已应用，两边不会打架。

-- ---------------------------------------------------------------- 组局级人数区间
ALTER TABLE game_groups ADD COLUMN IF NOT EXISTS min_players INTEGER NOT NULL DEFAULT 5;
ALTER TABLE game_groups ADD COLUMN IF NOT EXISTS max_players INTEGER NOT NULL DEFAULT 8;
ALTER TABLE game_groups DROP CONSTRAINT IF EXISTS ck_group_player_range;
ALTER TABLE game_groups ADD CONSTRAINT ck_group_player_range
    CHECK (min_players >= 2 AND max_players >= min_players AND max_players <= 20);

-- ---------------------------------------------------------------- 轮次快照本轮区间
-- capacity 改名为 max_players（含义不变：本轮签位总数）
ALTER TABLE game_rounds DROP CONSTRAINT IF EXISTS ck_round_capacity;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'game_rounds' AND column_name = 'capacity') THEN
        ALTER TABLE game_rounds RENAME COLUMN capacity TO max_players;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'game_rounds' AND column_name = 'min_players') THEN
        ALTER TABLE game_rounds ADD COLUMN min_players INTEGER NOT NULL DEFAULT 5;
        -- 历史轮次原来是「满员才算结束」，语义上 min = max，只在首次加列时对齐一次
        UPDATE game_rounds SET min_players = max_players;
    END IF;
END $$;

ALTER TABLE game_rounds DROP CONSTRAINT IF EXISTS ck_round_max_players;
ALTER TABLE game_rounds ADD CONSTRAINT ck_round_max_players
    CHECK (max_players >= 2 AND max_players <= 20);
ALTER TABLE game_rounds DROP CONSTRAINT IF EXISTS ck_round_min_players;
ALTER TABLE game_rounds ADD CONSTRAINT ck_round_min_players
    CHECK (min_players >= 2 AND min_players <= max_players);

-- 轮次不再区分 5 人局 / 8 人局
ALTER TABLE game_rounds DROP CONSTRAINT IF EXISTS ck_round_mode;
ALTER TABLE game_rounds DROP COLUMN IF EXISTS round_mode;

-- ---------------------------------------------------------------- 身份模板不再按人数区分
-- 只保留一套模板：沿用原 5 人局那套文案，管理员可在后台「身份内容」里修改
DELETE FROM role_templates WHERE round_mode = 'EIGHT';
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ux_template_mode_role;
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ck_template_mode;
ALTER TABLE role_templates DROP COLUMN IF EXISTS round_mode;
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ux_template_role;
ALTER TABLE role_templates ADD CONSTRAINT ux_template_role UNIQUE (role_type);

-- 囍签 · 手工执行 V3（人数区间）
--
-- 为什么需要手工执行：
--   线上库是早期用 SQL 手工建起来的（没有 flyway_schema_history 表），
--   而 Spring Boot 4 把 Flyway 自动配置拆到了独立模块，本项目 pom 里原先只引了
--   flyway-core，没有 spring-boot-flyway → Flyway 从未运行过，因此不会自动改结构。
--   （pom 已补上 spring-boot-starter-flyway，后续构建会自动迁移；本脚本用于补救当前库。）
--
-- 特点：可安全重复执行（全部语句幂等），但注意：
--   * 会删除 role_templates 里 round_mode='EIGHT' 的那套模板
--   * 会删除 game_rounds.round_mode 列
--   旧版本程序依赖这两处，所以执行后必须立刻发布新版本。
--
-- 用法：
--   sudo -u postgres psql -d xiqian -v ON_ERROR_STOP=1 -f manual-v3-migration.sql

BEGIN;

-- ---------------------------------------------------------------- 组局：人数区间
ALTER TABLE game_groups ADD COLUMN IF NOT EXISTS min_players INTEGER NOT NULL DEFAULT 5;
ALTER TABLE game_groups ADD COLUMN IF NOT EXISTS max_players INTEGER NOT NULL DEFAULT 8;
ALTER TABLE game_groups DROP CONSTRAINT IF EXISTS ck_group_player_range;
ALTER TABLE game_groups ADD CONSTRAINT ck_group_player_range
    CHECK (min_players >= 2 AND max_players >= min_players AND max_players <= 20);

-- ---------------------------------------------------------------- 轮次：区间快照
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

ALTER TABLE game_rounds DROP CONSTRAINT IF EXISTS ck_round_mode;
ALTER TABLE game_rounds DROP COLUMN IF EXISTS round_mode;

-- ---------------------------------------------------------------- 身份模板：不再按人数区分
-- 只保留一套（沿用原 5 人局那套文案，后台「身份内容」里可随时修改）
DELETE FROM role_templates WHERE round_mode = 'EIGHT';
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ux_template_mode_role;
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ck_template_mode;
ALTER TABLE role_templates DROP COLUMN IF EXISTS round_mode;
ALTER TABLE role_templates DROP CONSTRAINT IF EXISTS ux_template_role;
ALTER TABLE role_templates ADD CONSTRAINT ux_template_role UNIQUE (role_type);

COMMIT;

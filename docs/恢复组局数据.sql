-- ============================================================================
-- 囍签 · 恢复组局数据（万一清理脚本删错了）
--
-- 前提：跑过「清理组局数据.sql」的真删模式，它会在删除前自动生成三张备份表：
--     bak_game_groups / bak_game_rounds / bak_draw_slots
--
-- 用法（在服务器上）：
--     sudo -u postgres psql -d xiqian -v ON_ERROR_STOP=1 -f /root/恢复组局数据.sql
--
-- 说明：
--   * 已经存在的记录会跳过，不会重复插入；
--   * 恢复的是「清理之前那一刻」的完整快照，包括当时的抽签记录；
--   * 如果删除之后又新建了组局、并且恰好抽到同一个四位组局码，那一条旧组局会
--     恢复不了（组局码是唯一的），下面的数量对比会告诉你有没有漏；
--   * 本脚本同样不碰身份卡内容（role_templates）与故事简介（story_intro）。
-- ============================================================================

\set ON_ERROR_STOP on
\encoding UTF8

-- 先确认备份表还在，不在就直接停下并说明原因
DO $$
BEGIN
    IF to_regclass('public.bak_game_groups') IS NULL THEN
        RAISE EXCEPTION '找不到备份表 bak_game_groups，无法恢复：请确认清理脚本真的执行过删除。';
    END IF;
END $$;

BEGIN;

-- ① 先恢复组局本身（后面的轮次要靠它）
INSERT INTO game_groups
SELECT * FROM bak_game_groups
ON CONFLICT DO NOTHING;

-- ② 再恢复轮次：只恢复「组局确实存在」的那些，避免外键报错
INSERT INTO game_rounds
SELECT r.* FROM bak_game_rounds r
 WHERE EXISTS (SELECT 1 FROM game_groups g WHERE g.id = r.group_id)
ON CONFLICT DO NOTHING;

-- ③ 最后恢复签位与抽签记录
INSERT INTO draw_slots
SELECT s.* FROM bak_draw_slots s
 WHERE EXISTS (SELECT 1 FROM game_rounds r WHERE r.id = s.round_id)
ON CONFLICT DO NOTHING;

COMMIT;

\echo ''
\echo '========== 恢复后的数量对比 =========='

SELECT '组局 game_groups' AS "表", count(*) AS "当前行数", (SELECT count(*) FROM bak_game_groups) AS "备份行数" FROM game_groups
UNION ALL
SELECT '轮次 game_rounds',       count(*), (SELECT count(*) FROM bak_game_rounds) FROM game_rounds
UNION ALL
SELECT '签位 draw_slots',        count(*), (SELECT count(*) FROM bak_draw_slots)  FROM draw_slots;

\echo ''
\echo '若「当前行数」小于「备份行数」，说明有几条因为组局码被新组局占用而没能恢复。'
\echo '身份卡内容 role_templates 与故事简介 story_intro 全程没有被这两个脚本改动过。'

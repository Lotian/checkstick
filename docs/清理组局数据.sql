-- ============================================================================
-- 囍签 · 清理组局数据
--
-- 会删掉：
--     game_groups   组局本身（那些测试局）
--     game_rounds   这些组局下面的历史轮次
--     draw_slots    轮次里的签位与玩家抽取记录
--
-- 绝对不碰（一行都不动）：
--     role_templates   身份卡内容（新郎/新娘/村民的任务与奖励）
--     story_intro      玩家端故事简介
--
-- 用法（在服务器上）：
--     sudo -u postgres psql -d xiqian -v ON_ERROR_STOP=1 -f /root/清理组局数据.sql
--
-- 本脚本默认是「预览模式」，只读不删。确认预览没问题后，把下面第 ① 步的
-- do_delete 从 0 改成 1，再跑一次才会真正删除（删除前会自动备份，见第 ④ 步）。
--
-- ★ 删除前请确认现场没有玩家正在抽签；删完请刷新一下管理端页面。
-- ★ 只想看不想动数据，就一直别改那个 0。
-- ============================================================================

\set ON_ERROR_STOP on
\encoding UTF8

-- ============================================================================
-- ① 真删开关
-- ============================================================================
-- 0 = 预览模式（只显示会删掉什么，不动数据）
-- 1 = 真正删除（会先自动备份三张表，再删除）
\set do_delete 0

-- ============================================================================
-- ② 要保留哪些组局
-- ============================================================================
-- 默认「全删」：下面的 "WHERE false" 表示一个都不保留。
--
-- 想保留某几桌，把 "WHERE false" 改成（组局码看下面的预览列表）：
--     WHERE g.code IN ('2226', '7123')
--
-- ★★ 重点提醒：如果某张桌子的立牌已经印好、上面写着组局码，就务必把它加进
--    保留名单。那条记录一删，立牌上的码就作废了，玩家会提示「没有找到该组局」，
--    只能重新组局、重新印立牌。
DROP TABLE IF EXISTS pg_temp.keep_groups;
CREATE TEMP TABLE keep_groups AS
SELECT g.id FROM game_groups g
WHERE false;

-- ============================================================================
-- ③ 预览：现在有什么、会删掉什么（这一段只读）
-- ============================================================================
\echo ''
\echo '========== 当前所有组局（处理 = ★删 的会被删掉）=========='

SELECT
    CASE WHEN g.id IN (SELECT id FROM keep_groups) THEN '保留' ELSE '★删' END AS "处理",
    g.code                                        AS "组局码",
    g.name                                        AS "名称",
    CASE WHEN g.enabled THEN '启用' ELSE '已停用' END AS "状态",
    concat(g.min_players, '~', g.max_players)      AS "人数区间",
    (SELECT count(*) FROM game_rounds r WHERE r.group_id = g.id) AS "轮次数",
    (SELECT count(*) FROM draw_slots s
       JOIN game_rounds r2 ON r2.id = s.round_id
      WHERE r2.group_id = g.id AND s.visitor_id IS NOT NULL)     AS "已抽签数",
    to_char(g.created_at, 'MM-DD HH24:MI')         AS "建局时间"
FROM game_groups g
ORDER BY g.created_at DESC;

\echo ''
\echo '========== 将要删除的数量 =========='

SELECT
    (SELECT count(*) FROM game_groups g
      WHERE g.id NOT IN (SELECT id FROM keep_groups))  AS "组局",
    (SELECT count(*) FROM game_rounds r
      WHERE r.group_id NOT IN (SELECT id FROM keep_groups)) AS "轮次",
    (SELECT count(*) FROM draw_slots s
      WHERE s.round_id IN (SELECT r.id FROM game_rounds r
                            WHERE r.group_id NOT IN (SELECT id FROM keep_groups))) AS "签位记录";

-- ============================================================================
-- ④ 删除（受 ① 的开关控制）
-- ============================================================================
\if :do_delete

\echo ''
\echo '========== 已开启删除：先备份，再删除 =========='

BEGIN;

-- 4.1 备份整三张表，删错了可以用「恢复组局数据.sql」还原
DROP TABLE IF EXISTS bak_draw_slots;
DROP TABLE IF EXISTS bak_game_rounds;
DROP TABLE IF EXISTS bak_game_groups;
CREATE TABLE bak_draw_slots  AS SELECT * FROM draw_slots;
CREATE TABLE bak_game_rounds AS SELECT * FROM game_rounds;
CREATE TABLE bak_game_groups AS SELECT * FROM game_groups;

-- 4.2 签位记录（先删，因为它指向轮次）
DELETE FROM draw_slots
 WHERE round_id IN (SELECT r.id FROM game_rounds r
                     WHERE r.group_id NOT IN (SELECT id FROM keep_groups));

-- 4.3 轮次（再删；它指向组局，而外键没有级联，所以顺序不能反）
DELETE FROM game_rounds
 WHERE group_id NOT IN (SELECT id FROM keep_groups);

-- 4.4 最后才是组局本身
DELETE FROM game_groups
 WHERE id NOT IN (SELECT id FROM keep_groups);

COMMIT;

\echo '删除已完成并提交。备份表：bak_game_groups / bak_game_rounds / bak_draw_slots'

\else

\echo ''
\echo '========== 预览模式：没有删除任何数据 =========='
\echo '确认上面的列表没问题后，把文件开头的 do_delete 改成 1，再跑一次即可真正删除。'

\endif

-- ============================================================================
-- ⑤ 核对：身份卡内容和故事简介必须一行不少
-- ============================================================================
\echo ''
\echo '========== 核对结果 =========='

SELECT '身份卡内容 role_templates' AS "表", count(*) AS "行数", '必须是 3（新郎/新娘/村民）' AS "说明" FROM role_templates
UNION ALL
SELECT '故事简介 story_intro',      count(*), '必须是 1'   FROM story_intro
UNION ALL
SELECT '剩余组局 game_groups',      count(*), '按你的需要' FROM game_groups
UNION ALL
SELECT '剩余轮次 game_rounds',      count(*), ''          FROM game_rounds
UNION ALL
SELECT '剩余签位 draw_slots',       count(*), ''          FROM draw_slots;

\echo ''
\echo '========== 现在剩下的组局 =========='

SELECT
    g.code AS "组局码",
    g.name AS "名称",
    CASE WHEN g.enabled THEN '启用' ELSE '已停用' END AS "状态",
    concat(g.min_players, '~', g.max_players) AS "人数区间"
FROM game_groups g
ORDER BY g.created_at DESC;

# 数据库设计说明

## 关系

- `game_groups` 1:N `game_rounds`：一个组局可以连续开多轮。
- `game_rounds` 1:N `draw_slots`：每轮预生成并打乱 `max_players` 个签位。
- `role_templates` 每个身份一条（新郎/新娘/村民），不再按人数区分。

## 人数区间

- 组局上配置 `min_players` / `max_players`；开轮时把区间快照到轮次上，
  之后修改组局设置不影响已经开始的轮次。
- 签位数量 = `max_players`；抽满 `min_players` 后工作人员可以提前封签，
  抽满 `max_players` 自动封签（`status = FULL`）。
- 签位打乱时保证新郎、新娘都落在前 `min_players` 个签位内，
  这样只要抽满最低人数，两个主角必定都已出现，不会出现"本局没有新娘"。
- 轮次的 `status`：`ACTIVE` 抽签中 / `FULL` 已满员 / `CLOSED` 已封签（含提前封签与开新轮时自动关闭）。

## 一致性约束

- `game_groups.code` 全局唯一。
- 组局码为 4 位数字（0000~9999，共一万个码位），由后端用 `SecureRandom` 生成并允许前导零；
  列宽仍为 `VARCHAR(6)`，用于兼容早期 6 位字母数字码的历史数据，因此不需要数据迁移。
- 同一组局同一轮次号唯一。
- PostgreSQL 部分唯一索引保证同一组局最多有一个 `ACTIVE/FULL` 轮次。
- 同一轮内 `slot_index` 唯一。
- 同一轮内 `visitor_id` 唯一；其值为空时 PostgreSQL 允许存在多个未领取签位。
- 人数区间受约束保护：`2 <= min_players <= max_players <= 20`（至少要有新郎与新娘各一人）。
- 抽签事务先悲观锁定轮次，再领取签位，可防止并发重复及超额抽取。

## 快照策略

- 开轮时将模板中的 `task_text`、`reward_text` 复制到 `draw_slots`。管理员修改模板只影响后续轮次，历史结果始终保持活动当时的内容。
- 开轮时同样把人数区间快照到 `game_rounds`。

## 删除策略

删除轮次时签位通过外键级联删除；组局不提供物理删除接口，仅允许停用，以保留历史兑奖记录。

package com.xiqian.draw.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 身份模板：每个身份一套，不再按 5 人局 / 8 人局区分
 * （一局的人数由组局自定义，无法按固定人数分模板）。
 */
@Entity
@Table(name = "role_templates")
public class RoleTemplate {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_type", nullable = false, length = 16)
    private RoleType roleType;

    @Column(name = "task_text", nullable = false, columnDefinition = "text")
    private String taskText;

    @Column(name = "reward_text", nullable = false, columnDefinition = "text")
    private String rewardText;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected RoleTemplate() {
    }

    public void update(String taskText, String rewardText) {
        // 三种身份共用同一套编辑规则；村民默认无任务，但后台可按活动需要配置。
        this.taskText = normalize(taskText);
        this.rewardText = normalize(rewardText);
        this.updatedAt = OffsetDateTime.now();
    }

    private String normalize(String text) {
        return text == null ? "" : text.strip();
    }

    public UUID getId() { return id; }
    public RoleType getRoleType() { return roleType; }
    public String getTaskText() { return taskText; }
    public String getRewardText() { return rewardText; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}

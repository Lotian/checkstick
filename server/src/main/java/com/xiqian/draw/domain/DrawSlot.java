package com.xiqian.draw.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "draw_slots")
public class DrawSlot {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "round_id", nullable = false)
    private GameRound round;

    @Column(name = "slot_index", nullable = false)
    private int slotIndex;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_type", nullable = false, length = 16)
    private RoleType roleType;

    @Column(name = "task_text", nullable = false, columnDefinition = "text")
    private String taskText;

    @Column(name = "reward_text", nullable = false, columnDefinition = "text")
    private String rewardText;

    @Column(name = "visitor_id", length = 64)
    private String visitorId;

    @Column(name = "drawn_at")
    private OffsetDateTime drawnAt;

    protected DrawSlot() {
    }

    public DrawSlot(GameRound round, int slotIndex, RoleType roleType, String taskText, String rewardText) {
        this.id = UUID.randomUUID();
        this.round = round;
        this.slotIndex = slotIndex;
        this.roleType = roleType;
        this.taskText = taskText == null ? "" : taskText;
        this.rewardText = rewardText == null ? "" : rewardText;
    }

    public void claim(String visitorId) {
        if (this.visitorId != null) {
            throw new IllegalStateException("该签位已经被领取");
        }
        this.visitorId = visitorId;
        this.drawnAt = OffsetDateTime.now();
    }

    public UUID getId() { return id; }
    public GameRound getRound() { return round; }
    public int getSlotIndex() { return slotIndex; }
    public RoleType getRoleType() { return roleType; }
    public String getTaskText() { return taskText; }
    public String getRewardText() { return rewardText; }
    public String getVisitorId() { return visitorId; }
    public OffsetDateTime getDrawnAt() { return drawnAt; }
}

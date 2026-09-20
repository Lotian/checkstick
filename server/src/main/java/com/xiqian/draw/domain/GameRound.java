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
@Table(name = "game_rounds")
public class GameRound {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "group_id", nullable = false)
    private GameGroup group;

    @Column(name = "round_number", nullable = false)
    private int roundNumber;

    /**
     * 本轮人数下限：抽满这个人数后，工作人员可以提前封签。
     * 开轮时从组局配置快照下来，之后改组局设置不影响已经开始的轮次。
     */
    @Column(name = "min_players", nullable = false)
    private int minPlayers;

    /** 本轮人数上限，同时也是签位总数；抽满自动封签。 */
    @Column(name = "max_players", nullable = false)
    private int maxPlayers;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private RoundStatus status;

    @Column(name = "started_at", nullable = false)
    private OffsetDateTime startedAt;

    @Column(name = "closed_at")
    private OffsetDateTime closedAt;

    protected GameRound() {
    }

    public GameRound(GameGroup group, int roundNumber, int minPlayers, int maxPlayers) {
        this.id = UUID.randomUUID();
        this.group = group;
        this.roundNumber = roundNumber;
        this.minPlayers = minPlayers;
        this.maxPlayers = maxPlayers;
        this.status = RoundStatus.ACTIVE;
        this.startedAt = OffsetDateTime.now();
    }

    public void markFull() {
        this.status = RoundStatus.FULL;
    }

    /** 关闭本轮：满员自动封签与工作人员提前封签都走这里。 */
    public void close() {
        this.status = RoundStatus.CLOSED;
        this.closedAt = OffsetDateTime.now();
    }

    public UUID getId() { return id; }
    public GameGroup getGroup() { return group; }
    public int getRoundNumber() { return roundNumber; }
    public int getMinPlayers() { return minPlayers; }
    public int getMaxPlayers() { return maxPlayers; }
    public RoundStatus getStatus() { return status; }
    public OffsetDateTime getStartedAt() { return startedAt; }
    public OffsetDateTime getClosedAt() { return closedAt; }
}

package com.xiqian.draw.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "game_groups")
public class GameGroup {

    /** 人数区间的合理边界：至少 2 人（需要新郎与新娘各一人），最多 20 人。 */
    public static final int MIN_PLAYERS_LIMIT = 2;
    public static final int MAX_PLAYERS_LIMIT = 20;
    public static final int DEFAULT_MIN_PLAYERS = 5;
    public static final int DEFAULT_MAX_PLAYERS = 8;

    @Id
    private UUID id;

    @Column(nullable = false, length = 80)
    private String name;

    @Column(nullable = false, unique = true, length = 6)
    private String code;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "min_players", nullable = false)
    private int minPlayers;

    @Column(name = "max_players", nullable = false)
    private int maxPlayers;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected GameGroup() {
    }

    public GameGroup(String name, String code) {
        this(name, code, DEFAULT_MIN_PLAYERS, DEFAULT_MAX_PLAYERS);
    }

    public GameGroup(String name, String code, int minPlayers, int maxPlayers) {
        OffsetDateTime now = OffsetDateTime.now();
        this.id = UUID.randomUUID();
        this.name = name;
        this.code = code;
        this.enabled = true;
        this.minPlayers = minPlayers;
        this.maxPlayers = maxPlayers;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void update(String name, Boolean enabled, Integer minPlayers, Integer maxPlayers) {
        if (name != null && !name.isBlank()) {
            this.name = name.trim();
        }
        if (enabled != null) {
            this.enabled = enabled;
        }
        if (minPlayers != null) {
            this.minPlayers = minPlayers;
        }
        if (maxPlayers != null) {
            this.maxPlayers = maxPlayers;
        }
        this.updatedAt = OffsetDateTime.now();
    }

    public UUID getId() { return id; }
    public String getName() { return name; }
    public String getCode() { return code; }
    public boolean isEnabled() { return enabled; }
    public int getMinPlayers() { return minPlayers; }
    public int getMaxPlayers() { return maxPlayers; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}

package com.xiqian.draw.api.dto;

import com.xiqian.draw.domain.GameGroup;
import com.xiqian.draw.domain.RoundStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.UUID;

public final class GroupDtos {
    private GroupDtos() {
    }

    public record CreateGroupRequest(
            @NotBlank(message = "请输入组局名称")
            @Size(max = 80, message = "组局名称不能超过80个字符")
            String name,

            @Min(value = GameGroup.MIN_PLAYERS_LIMIT, message = "最低人数不能少于2人")
            @Max(value = GameGroup.MAX_PLAYERS_LIMIT, message = "最低人数不能超过20人")
            Integer minPlayers,

            @Min(value = GameGroup.MIN_PLAYERS_LIMIT, message = "最高人数不能少于2人")
            @Max(value = GameGroup.MAX_PLAYERS_LIMIT, message = "最高人数不能超过20人")
            Integer maxPlayers
    ) {
    }

    public record UpdateGroupRequest(
            @Size(max = 80, message = "组局名称不能超过80个字符")
            String name,

            Boolean enabled,

            @Min(value = GameGroup.MIN_PLAYERS_LIMIT, message = "最低人数不能少于2人")
            @Max(value = GameGroup.MAX_PLAYERS_LIMIT, message = "最低人数不能超过20人")
            Integer minPlayers,

            @Min(value = GameGroup.MIN_PLAYERS_LIMIT, message = "最高人数不能少于2人")
            @Max(value = GameGroup.MAX_PLAYERS_LIMIT, message = "最高人数不能超过20人")
            Integer maxPlayers
    ) {
    }

    public record CurrentRoundSummary(
            UUID id,
            int roundNumber,
            int minPlayers,
            int maxPlayers,
            RoundStatus status,
            long drawnCount,
            OffsetDateTime startedAt
    ) {
    }

    public record GroupResponse(
            UUID id,
            String name,
            String code,
            boolean enabled,
            int minPlayers,
            int maxPlayers,
            OffsetDateTime createdAt,
            CurrentRoundSummary currentRound
    ) {
    }
}

package com.xiqian.draw.api.dto;

import com.xiqian.draw.domain.RoleType;
import com.xiqian.draw.domain.RoundStatus;

import java.time.OffsetDateTime;
import java.util.UUID;

public final class PublicDtos {
    private PublicDtos() {
    }

    public record DrawResult(
            UUID roundId,
            RoleType roleType,
            String roleName,
            String taskText,
            String rewardText,
            OffsetDateTime drawnAt
    ) {
    }

    public record PublicGroupState(
            UUID groupId,
            String groupName,
            String groupCode,
            UUID roundId,
            Integer roundNumber,
            Integer minPlayers,
            Integer maxPlayers,
            RoundStatus roundStatus,
            long drawnCount,
            long remainingCount,
            DrawResult result
    ) {
    }
}

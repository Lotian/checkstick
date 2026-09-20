package com.xiqian.draw.api.dto;

import com.xiqian.draw.domain.RoleType;
import com.xiqian.draw.domain.RoundStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class RoundDtos {
    private RoundDtos() {
    }

    public record DrawDetail(
            UUID slotId,
            int slotIndex,
            RoleType roleType,
            String roleName,
            String visitorId,
            OffsetDateTime drawnAt
    ) {
    }

    public record RoundResponse(
            UUID id,
            UUID groupId,
            String groupName,
            int roundNumber,
            int minPlayers,
            int maxPlayers,
            RoundStatus status,
            long drawnCount,
            long remainingCount,
            OffsetDateTime startedAt,
            OffsetDateTime closedAt,
            boolean canCloseEarly,
            List<DrawDetail> draws
    ) {
    }

    public record RoundListItem(
            UUID id,
            int roundNumber,
            int minPlayers,
            int maxPlayers,
            RoundStatus status,
            long drawnCount,
            OffsetDateTime startedAt,
            OffsetDateTime closedAt
    ) {
    }
}

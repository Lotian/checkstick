package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.GroupDtos;
import com.xiqian.draw.api.dto.PublicDtos;
import com.xiqian.draw.api.dto.RoundDtos;
import com.xiqian.draw.domain.DrawSlot;
import com.xiqian.draw.domain.GameRound;
import com.xiqian.draw.domain.RoundStatus;
import com.xiqian.draw.repository.DrawSlotRepository;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class RoundMapper {

    private final DrawSlotRepository drawSlotRepository;

    public RoundMapper(DrawSlotRepository drawSlotRepository) {
        this.drawSlotRepository = drawSlotRepository;
    }

    public GroupDtos.CurrentRoundSummary toSummary(GameRound round) {
        long drawnCount = drawSlotRepository.countByRoundIdAndVisitorIdIsNotNull(round.getId());
        return new GroupDtos.CurrentRoundSummary(
                round.getId(), round.getRoundNumber(), round.getMinPlayers(), round.getMaxPlayers(),
                round.getStatus(), drawnCount, round.getStartedAt());
    }

    public RoundDtos.RoundResponse toResponse(GameRound round) {
        List<DrawSlot> slots = drawSlotRepository.findAllByRoundIdOrderBySlotIndexAsc(round.getId());
        List<RoundDtos.DrawDetail> draws = slots.stream()
                .filter(slot -> slot.getVisitorId() != null)
                .map(slot -> new RoundDtos.DrawDetail(
                        slot.getId(), slot.getSlotIndex(), slot.getRoleType(),
                        slot.getRoleType().getDisplayName(), slot.getVisitorId(), slot.getDrawnAt()))
                .toList();
        long drawnCount = draws.size();
        return new RoundDtos.RoundResponse(
                round.getId(), round.getGroup().getId(), round.getGroup().getName(),
                round.getRoundNumber(), round.getMinPlayers(), round.getMaxPlayers(), round.getStatus(),
                drawnCount, round.getMaxPlayers() - drawnCount, round.getStartedAt(),
                round.getClosedAt(), canCloseEarly(round, drawnCount), draws);
    }

    public RoundDtos.RoundListItem toListItem(GameRound round) {
        long drawnCount = drawSlotRepository.countByRoundIdAndVisitorIdIsNotNull(round.getId());
        return new RoundDtos.RoundListItem(
                round.getId(), round.getRoundNumber(), round.getMinPlayers(), round.getMaxPlayers(),
                round.getStatus(), drawnCount, round.getStartedAt(), round.getClosedAt());
    }

    public PublicDtos.DrawResult toDrawResult(DrawSlot slot) {
        return new PublicDtos.DrawResult(
                slot.getRound().getId(), slot.getRoleType(), slot.getRoleType().getDisplayName(),
                slot.getTaskText(), slot.getRewardText(), slot.getDrawnAt());
    }

    /** 本轮是否已抽满最低人数、可以由工作人员提前封签。 */
    private boolean canCloseEarly(GameRound round, long drawnCount) {
        return round.getStatus() == RoundStatus.ACTIVE && drawnCount >= round.getMinPlayers();
    }
}

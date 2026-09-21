package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.PublicDtos;
import com.xiqian.draw.domain.DrawSlot;
import com.xiqian.draw.domain.GameGroup;
import com.xiqian.draw.domain.GameRound;
import com.xiqian.draw.domain.RoundStatus;
import com.xiqian.draw.repository.DrawSlotRepository;
import com.xiqian.draw.repository.GameGroupRepository;
import com.xiqian.draw.repository.GameRoundRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class DrawService {

    private static final List<RoundStatus> CURRENT_STATUSES = List.of(RoundStatus.ACTIVE, RoundStatus.FULL);

    private final GameGroupRepository groupRepository;
    private final GameRoundRepository roundRepository;
    private final DrawSlotRepository slotRepository;
    private final RoundMapper roundMapper;
    private final ApplicationEventPublisher eventPublisher;

    public DrawService(GameGroupRepository groupRepository,
                       GameRoundRepository roundRepository,
                       DrawSlotRepository slotRepository,
                       RoundMapper roundMapper,
                       ApplicationEventPublisher eventPublisher) {
        this.groupRepository = groupRepository;
        this.roundRepository = roundRepository;
        this.slotRepository = slotRepository;
        this.roundMapper = roundMapper;
        this.eventPublisher = eventPublisher;
    }

    @Transactional(readOnly = true)
    public PublicDtos.PublicGroupState state(String code, String visitorId) {
        String normalizedVisitor = normalizeVisitor(visitorId);
        GameGroup group = findEnabledGroup(code);
        GameRound round = roundRepository
                .findFirstByGroupIdAndStatusInOrderByStartedAtDesc(group.getId(), CURRENT_STATUSES)
                .orElse(null);
        if (round == null) {
            return new PublicDtos.PublicGroupState(
                    group.getId(), group.getName(), group.getCode(), null, null,
                    null, null, null, 0, 0, null);
        }
        long drawn = slotRepository.countByRoundIdAndVisitorIdIsNotNull(round.getId());
        PublicDtos.DrawResult result = slotRepository.findByRoundIdAndVisitorId(round.getId(), normalizedVisitor)
                .map(roundMapper::toDrawResult)
                .orElse(null);
        // 理论上 drawn 不会超过 maxPlayers；仍做下限保护，避免历史脏数据向前端返回负余量。
        long remaining = Math.max(0, round.getMaxPlayers() - drawn);
        return new PublicDtos.PublicGroupState(
                group.getId(), group.getName(), group.getCode(), round.getId(), round.getRoundNumber(),
                round.getMinPlayers(), round.getMaxPlayers(), round.getStatus(), drawn,
                remaining, result);
    }

    @Transactional
    public PublicDtos.DrawResult draw(String code, String visitorId) {
        String normalizedVisitor = normalizeVisitor(visitorId);
        GameGroup group = findEnabledGroup(code);
        GameRound round = roundRepository.findCurrentForUpdate(group.getId(), CURRENT_STATUSES)
                .orElseThrow(() -> new ConflictException("本组还没有开始新的轮次"));

        // 幂等检查必须放在“满员”判断之前：最后一位玩家重试请求时仍应拿回自己的原结果。
        DrawSlot existing = slotRepository.findByRoundIdAndVisitorId(round.getId(), normalizedVisitor)
                .orElse(null);
        if (existing != null) {
            return roundMapper.toDrawResult(existing);
        }
        if (round.getStatus() == RoundStatus.FULL) {
            throw new ConflictException("本轮已满员，请等待工作人员开新轮");
        }

        DrawSlot slot = slotRepository.findFirstByRoundIdAndVisitorIdIsNullOrderBySlotIndexAsc(round.getId())
                .orElseThrow(() -> new ConflictException("本轮已满员，请等待工作人员开新轮"));
        slot.claim(normalizedVisitor);
        slotRepository.saveAndFlush(slot);

        long drawn = slotRepository.countByRoundIdAndVisitorIdIsNotNull(round.getId());
        if (drawn >= round.getMaxPlayers()) {
            round.markFull();
        }
        eventPublisher.publishEvent(new DrawCompletedEvent(round.getId()));
        return roundMapper.toDrawResult(slot);
    }

    private GameGroup findEnabledGroup(String code) {
        if (code == null || !code.trim().matches("\\d{4}")) {
            throw new BadRequestException("请输入正确的4位数字组局码");
        }
        GameGroup group = groupRepository.findByCodeIgnoreCase(code.trim())
                .orElseThrow(() -> new NotFoundException("没有找到该组局，请核对组局码"));
        if (!group.isEnabled()) {
            throw new ConflictException("该组局已经停用");
        }
        return group;
    }

    private String normalizeVisitor(String visitorId) {
        try {
            return UUID.fromString(visitorId).toString();
        } catch (IllegalArgumentException | NullPointerException exception) {
            throw new BadRequestException("游客标识无效，请刷新页面重试");
        }
    }
}

package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.RoundDtos;
import com.xiqian.draw.domain.DrawSlot;
import com.xiqian.draw.domain.GameGroup;
import com.xiqian.draw.domain.GameRound;
import com.xiqian.draw.domain.RoleTemplate;
import com.xiqian.draw.domain.RoleType;
import com.xiqian.draw.domain.RoundStatus;
import com.xiqian.draw.repository.DrawSlotRepository;
import com.xiqian.draw.repository.GameRoundRepository;
import com.xiqian.draw.repository.RoleTemplateRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.List;
import java.util.UUID;

@Service
public class RoundService {

    private static final List<RoundStatus> CURRENT_STATUSES = List.of(RoundStatus.ACTIVE, RoundStatus.FULL);

    private final EntityManager entityManager;
    private final GameRoundRepository roundRepository;
    private final RoleTemplateRepository templateRepository;
    private final DrawSlotRepository slotRepository;
    private final RoundMapper roundMapper;
    private final SecureRandom secureRandom = new SecureRandom();

    public RoundService(EntityManager entityManager,
                        GameRoundRepository roundRepository,
                        RoleTemplateRepository templateRepository,
                        DrawSlotRepository slotRepository,
                        RoundMapper roundMapper) {
        this.entityManager = entityManager;
        this.roundRepository = roundRepository;
        this.templateRepository = templateRepository;
        this.slotRepository = slotRepository;
        this.roundMapper = roundMapper;
    }

    /**
     * 开新轮：按组局配置的人数区间生成签位（签位数量 = 最高人数），
     * 并把当前未结束的轮次关闭。
     */
    @Transactional
    public RoundDtos.RoundResponse start(UUID groupId) {
        // 同一组局只能串行开轮。锁住组局行后，两个管理员标签页同时点击也不会生成两轮“当前轮”。
        GameGroup group = entityManager.find(GameGroup.class, groupId, LockModeType.PESSIMISTIC_WRITE);
        if (group == null) {
            throw new NotFoundException("组局不存在");
        }
        if (!group.isEnabled()) {
            throw new ConflictException("该组局已停用，不能开新轮");
        }

        // 人数在开轮时形成快照；之后调整组局配置，只影响下一轮。
        int minPlayers = group.getMinPlayers();
        int maxPlayers = group.getMaxPlayers();

        // 数据库只允许每个组局存在一个 ACTIVE/FULL 轮次，创建前必须先关闭旧轮。
        roundRepository.findCurrentForUpdate(groupId, CURRENT_STATUSES).ifPresent(current -> {
            current.close();
            roundRepository.saveAndFlush(current);
        });

        int nextNumber = roundRepository.findFirstByGroupIdOrderByRoundNumberDesc(groupId)
                .map(previous -> previous.getRoundNumber() + 1)
                .orElse(1);
        GameRound round = roundRepository.saveAndFlush(
                new GameRound(group, nextNumber, minPlayers, maxPlayers));

        List<RoleType> roles = RoundSlotPlanner.plan(minPlayers, maxPlayers, secureRandom);
        for (int i = 0; i < roles.size(); i++) {
            RoleType role = roles.get(i);
            RoleTemplate template = templateRepository.findByRoleType(role)
                    .orElseThrow(() -> new IllegalStateException("缺少身份模板：" + role));
            // 任务与奖励复制进签位，确保后台后来修改模板时不会改变已经开出的签。
            slotRepository.save(new DrawSlot(round, i + 1, role, template.getTaskText(), template.getRewardText()));
        }
        slotRepository.flush();
        return roundMapper.toResponse(round);
    }

    /**
     * 提前封签：抽满最低人数后，工作人员可以不再等满最高人数，直接结束本轮（剩余签位作废）。
     */
    @Transactional
    public RoundDtos.RoundResponse closeEarly(UUID roundId) {
        GameRound round = roundRepository.findByIdForUpdate(roundId)
                .orElseThrow(() -> new NotFoundException("轮次不存在"));
        if (round.getStatus() == RoundStatus.CLOSED) {
            throw new ConflictException("本轮已经封签");
        }

        long drawnCount = slotRepository.countByRoundIdAndVisitorIdIsNotNull(round.getId());
        if (drawnCount < round.getMinPlayers()) {
            throw new ConflictException(
                    "本局至少需要 " + round.getMinPlayers() + " 人才能封签，当前已抽 " + drawnCount + " 人");
        }

        round.close();
        roundRepository.saveAndFlush(round);
        return roundMapper.toResponse(round);
    }

    @Transactional(readOnly = true)
    public RoundDtos.RoundResponse get(UUID id) {
        GameRound round = roundRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("轮次不存在"));
        return roundMapper.toResponse(round);
    }

    @Transactional(readOnly = true)
    public List<RoundDtos.RoundListItem> history(UUID groupId) {
        return roundRepository.findAllByGroupIdOrderByRoundNumberDesc(groupId).stream()
                .map(roundMapper::toListItem)
                .toList();
    }
}

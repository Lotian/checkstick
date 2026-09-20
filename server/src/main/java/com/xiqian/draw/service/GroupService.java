package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.GroupDtos;
import com.xiqian.draw.domain.GameGroup;
import com.xiqian.draw.domain.GameRound;
import com.xiqian.draw.domain.RoundStatus;
import com.xiqian.draw.repository.GameGroupRepository;
import com.xiqian.draw.repository.GameRoundRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class GroupService {

    private static final List<RoundStatus> CURRENT_STATUSES = List.of(RoundStatus.ACTIVE, RoundStatus.FULL);

    private final GameGroupRepository groupRepository;
    private final GameRoundRepository roundRepository;
    private final GroupCodeGenerator codeGenerator;
    private final RoundMapper roundMapper;

    public GroupService(GameGroupRepository groupRepository,
                        GameRoundRepository roundRepository,
                        GroupCodeGenerator codeGenerator,
                        RoundMapper roundMapper) {
        this.groupRepository = groupRepository;
        this.roundRepository = roundRepository;
        this.codeGenerator = codeGenerator;
        this.roundMapper = roundMapper;
    }

    @Transactional(readOnly = true)
    public List<GroupDtos.GroupResponse> list() {
        return groupRepository.findAllByOrderByCreatedAtDesc().stream().map(this::toResponse).toList();
    }

    @Transactional
    public GroupDtos.GroupResponse create(GroupDtos.CreateGroupRequest request) {
        int minPlayers = request.minPlayers() == null
                ? GameGroup.DEFAULT_MIN_PLAYERS : request.minPlayers();
        int maxPlayers = request.maxPlayers() == null
                ? GameGroup.DEFAULT_MAX_PLAYERS : request.maxPlayers();
        validatePlayerRange(minPlayers, maxPlayers);

        String code = uniqueCode();
        GameGroup group = groupRepository.save(
                new GameGroup(request.name().trim(), code, minPlayers, maxPlayers));
        return toResponse(group);
    }

    @Transactional
    public GroupDtos.GroupResponse update(UUID id, GroupDtos.UpdateGroupRequest request) {
        GameGroup group = groupRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("组局不存在"));

        // 只校验改动后的最终区间：允许只改其中一个值时与现有值组合
        int minPlayers = request.minPlayers() == null ? group.getMinPlayers() : request.minPlayers();
        int maxPlayers = request.maxPlayers() == null ? group.getMaxPlayers() : request.maxPlayers();
        validatePlayerRange(minPlayers, maxPlayers);

        group.update(request.name(), request.enabled(), request.minPlayers(), request.maxPlayers());
        return toResponse(group);
    }

    private void validatePlayerRange(int minPlayers, int maxPlayers) {
        if (minPlayers < GameGroup.MIN_PLAYERS_LIMIT) {
            throw new BadRequestException(
                    "最低人数不能少于" + GameGroup.MIN_PLAYERS_LIMIT + "人（至少要有新郎与新娘各一人）");
        }
        if (maxPlayers > GameGroup.MAX_PLAYERS_LIMIT) {
            throw new BadRequestException("最高人数不能超过" + GameGroup.MAX_PLAYERS_LIMIT + "人");
        }
        if (maxPlayers < minPlayers) {
            throw new BadRequestException("最高人数不能小于最低人数");
        }
    }

    private String uniqueCode() {
        for (int i = 0; i < 20; i++) {
            String code = codeGenerator.nextCode();
            if (!groupRepository.existsByCode(code)) {
                return code;
            }
        }
        throw new IllegalStateException("暂时无法生成组局码，请稍后重试");
    }

    private GroupDtos.GroupResponse toResponse(GameGroup group) {
        GameRound current = roundRepository
                .findFirstByGroupIdAndStatusInOrderByStartedAtDesc(group.getId(), CURRENT_STATUSES)
                .orElse(null);
        return new GroupDtos.GroupResponse(
                group.getId(), group.getName(), group.getCode(), group.isEnabled(),
                group.getMinPlayers(), group.getMaxPlayers(), group.getCreatedAt(),
                current == null ? null : roundMapper.toSummary(current));
    }
}

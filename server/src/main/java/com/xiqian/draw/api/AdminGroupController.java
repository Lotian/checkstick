package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.GroupDtos;
import com.xiqian.draw.api.dto.RoundDtos;
import com.xiqian.draw.service.GroupService;
import com.xiqian.draw.service.RoundService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/groups")
public class AdminGroupController {

    private final GroupService groupService;
    private final RoundService roundService;

    public AdminGroupController(GroupService groupService, RoundService roundService) {
        this.groupService = groupService;
        this.roundService = roundService;
    }

    @GetMapping
    public List<GroupDtos.GroupResponse> list() {
        return groupService.list();
    }

    @PostMapping
    public GroupDtos.GroupResponse create(@Valid @RequestBody GroupDtos.CreateGroupRequest request) {
        return groupService.create(request);
    }

    @PatchMapping("/{id}")
    public GroupDtos.GroupResponse update(@PathVariable UUID id,
                                           @Valid @RequestBody GroupDtos.UpdateGroupRequest request) {
        return groupService.update(id, request);
    }

    /** 开新轮：人数区间取自该组局的配置（最低人数~最高人数），不需要请求体。 */
    @PostMapping("/{id}/rounds")
    public RoundDtos.RoundResponse startRound(@PathVariable UUID id) {
        return roundService.start(id);
    }

    @GetMapping("/{id}/rounds")
    public List<RoundDtos.RoundListItem> history(@PathVariable UUID id) {
        return roundService.history(id);
    }
}

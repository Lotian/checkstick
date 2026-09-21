package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.TemplateDtos;
import com.xiqian.draw.domain.RoleTemplate;
import com.xiqian.draw.domain.RoleType;
import com.xiqian.draw.repository.RoleTemplateRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.EnumSet;
import java.util.List;

@Service
public class RoleTemplateService {

    private final RoleTemplateRepository repository;

    public RoleTemplateService(RoleTemplateRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<TemplateDtos.TemplateResponse> list() {
        return repository.findAllByOrderByRoleTypeAsc().stream().map(this::toResponse).toList();
    }

    @Transactional
    public List<TemplateDtos.TemplateResponse> update(TemplateDtos.UpdateTemplatesRequest request) {
        // 同一身份出现两次时，后一个值会悄悄覆盖前一个值。直接拒绝可尽早暴露前端载荷错误。
        EnumSet<RoleType> updatedRoles = EnumSet.noneOf(RoleType.class);
        request.templates().forEach(item -> {
            if (!updatedRoles.add(item.roleType())) {
                throw new BadRequestException("身份模板不能重复：" + item.roleType().getDisplayName());
            }
            RoleTemplate template = repository.findByRoleType(item.roleType())
                    .orElseThrow(() -> new NotFoundException("身份模板不存在"));
            template.update(item.taskText(), item.rewardText());
        });
        repository.flush();
        return list();
    }

    private TemplateDtos.TemplateResponse toResponse(RoleTemplate template) {
        return new TemplateDtos.TemplateResponse(
                template.getId(), template.getRoleType(), template.getRoleType().getDisplayName(),
                template.getTaskText(), template.getRewardText(), template.getUpdatedAt());
    }
}

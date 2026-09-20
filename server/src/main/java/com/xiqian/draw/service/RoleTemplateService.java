package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.TemplateDtos;
import com.xiqian.draw.domain.RoleTemplate;
import com.xiqian.draw.repository.RoleTemplateRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
        request.templates().forEach(item -> {
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

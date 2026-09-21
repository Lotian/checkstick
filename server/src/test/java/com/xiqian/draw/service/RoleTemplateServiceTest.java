package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.TemplateDtos;
import com.xiqian.draw.domain.RoleTemplate;
import com.xiqian.draw.domain.RoleType;
import com.xiqian.draw.repository.RoleTemplateRepository;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class RoleTemplateServiceTest {

    @Test
    void shouldRejectDuplicateRoleInSingleBatch() {
        RoleTemplateRepository repository = mock(RoleTemplateRepository.class);
        when(repository.findByRoleType(RoleType.GROOM))
                .thenReturn(Optional.of(mock(RoleTemplate.class)));
        RoleTemplateService service = new RoleTemplateService(repository);
        TemplateDtos.TemplateUpdateItem first =
                new TemplateDtos.TemplateUpdateItem(RoleType.GROOM, "任务一", "奖励一");
        TemplateDtos.TemplateUpdateItem duplicate =
                new TemplateDtos.TemplateUpdateItem(RoleType.GROOM, "任务二", "奖励二");
        TemplateDtos.UpdateTemplatesRequest request =
                new TemplateDtos.UpdateTemplatesRequest(List.of(first, duplicate));

        assertThatThrownBy(() -> service.update(request))
                .isInstanceOf(BadRequestException.class)
                .hasMessage("身份模板不能重复：新郎");
    }
}

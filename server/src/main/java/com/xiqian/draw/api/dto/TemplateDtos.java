package com.xiqian.draw.api.dto;

import com.xiqian.draw.domain.RoleType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class TemplateDtos {
    private TemplateDtos() {
    }

    public record TemplateResponse(
            UUID id,
            RoleType roleType,
            String roleName,
            String taskText,
            String rewardText,
            OffsetDateTime updatedAt
    ) {
    }

    public record TemplateUpdateItem(
            @NotNull RoleType roleType,
            @Size(max = 4000, message = "任务文本不能超过4000个字符") String taskText,
            @Size(max = 1000, message = "奖励文本不能超过1000个字符") String rewardText
    ) {
    }

    public record UpdateTemplatesRequest(
            @NotNull
            @Size(min = 1, max = 3, message = "每次请提交1至3个身份模板")
            @Valid
            List<TemplateUpdateItem> templates
    ) {
    }
}

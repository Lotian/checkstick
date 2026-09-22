package com.xiqian.draw.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

public final class StoryIntroDtos {
    private StoryIntroDtos() {
    }

    public record StoryIntroResponse(
            String title,
            String subtitle,
            String introText,
            String warningText,
            OffsetDateTime updatedAt
    ) {
    }

    public record UpdateStoryIntroRequest(
            @NotBlank(message = "故事标题不能为空")
            @Size(max = 80, message = "故事标题不能超过80个字符") String title,
            @Size(max = 160, message = "故事副标题不能超过160个字符") String subtitle,
            @NotBlank(message = "故事简介不能为空")
            @Size(max = 4000, message = "故事简介不能超过4000个字符") String introText,
            @Size(max = 2000, message = "安全提示不能超过2000个字符") String warningText
    ) {
    }
}

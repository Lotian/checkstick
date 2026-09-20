package com.xiqian.draw.api.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record ApiError(
        String code,
        String message,
        OffsetDateTime timestamp,
        Map<String, String> fieldErrors
) {
}

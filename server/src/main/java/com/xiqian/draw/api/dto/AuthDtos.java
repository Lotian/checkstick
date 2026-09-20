package com.xiqian.draw.api.dto;

import jakarta.validation.constraints.NotBlank;

public final class AuthDtos {
    private AuthDtos() {
    }

    public record LoginRequest(
            @NotBlank(message = "请输入用户名") String username,
            @NotBlank(message = "请输入密码") String password
    ) {
    }

    public record AuthResponse(String username, boolean authenticated) {
    }

    public record CsrfResponse(String token, String headerName) {
    }
}


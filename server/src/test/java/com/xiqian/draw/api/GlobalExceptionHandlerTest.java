package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.ApiError;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void shouldReturnUnauthorizedForBadCredentials() {
        ResponseEntity<ApiError> response =
                handler.authentication(new BadCredentialsException("bad credentials"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo("UNAUTHORIZED");
        assertThat(response.getBody().message()).isEqualTo("管理员账号或密码错误");
    }
}

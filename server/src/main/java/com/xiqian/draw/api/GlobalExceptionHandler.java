package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.ApiError;
import com.xiqian.draw.service.BadRequestException;
import com.xiqian.draw.service.ConflictException;
import com.xiqian.draw.service.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOGGER = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ApiError> notFound(NotFoundException exception) {
        return error(HttpStatus.NOT_FOUND, "NOT_FOUND", exception.getMessage());
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ApiError> conflict(ConflictException exception) {
        return error(HttpStatus.CONFLICT, "CONFLICT", exception.getMessage());
    }

    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<ApiError> badRequest(BadRequestException exception) {
        return error(HttpStatus.BAD_REQUEST, "BAD_REQUEST", exception.getMessage());
    }

    /** 登录失败属于可预期的认证结果，不能落入兜底处理后被误报为 500。 */
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiError> authentication(AuthenticationException exception) {
        return error(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "管理员账号或密码错误");
    }

    /** JSON 语法错误、枚举值错误与 UUID 路径错误统一返回可操作的 400 响应。 */
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<ApiError> malformedRequest(Exception exception) {
        return error(HttpStatus.BAD_REQUEST, "BAD_REQUEST", "请求格式有误，请检查后重试");
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> validation(MethodArgumentNotValidException exception) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (FieldError fieldError : exception.getBindingResult().getFieldErrors()) {
            fields.putIfAbsent(fieldError.getField(), fieldError.getDefaultMessage());
        }
        ApiError body = new ApiError("VALIDATION_ERROR", "提交内容有误，请检查后重试",
                OffsetDateTime.now(), fields);
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> unexpected(Exception exception) {
        // 响应不暴露内部异常，但服务端日志必须保留堆栈，便于现场定位故障。
        LOGGER.error("未处理的服务端异常", exception);
        ApiError body = new ApiError("INTERNAL_ERROR", "系统暂时无法处理请求，请稍后重试",
                OffsetDateTime.now(), Map.of());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }

    private ResponseEntity<ApiError> error(HttpStatus status, String code, String message) {
        return ResponseEntity.status(status)
                .body(new ApiError(code, message, OffsetDateTime.now(), Map.of()));
    }
}


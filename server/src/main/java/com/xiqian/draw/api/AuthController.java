package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.AuthDtos;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final SecurityContextRepository securityContextRepository;

    public AuthController(AuthenticationManager authenticationManager,
                          SecurityContextRepository securityContextRepository) {
        this.authenticationManager = authenticationManager;
        this.securityContextRepository = securityContextRepository;
    }

    @PostMapping("/login")
    public AuthDtos.AuthResponse login(@Valid @RequestBody AuthDtos.LoginRequest request,
                                       HttpServletRequest servletRequest,
                                       HttpServletResponse servletResponse) {
        // 项目关闭了表单登录，因此在 JSON 接口中显式完成认证并保存到 HTTP Session。
        Authentication authentication = authenticationManager.authenticate(
                UsernamePasswordAuthenticationToken.unauthenticated(request.username(), request.password()));
        var context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
        securityContextRepository.saveContext(context, servletRequest, servletResponse);
        return new AuthDtos.AuthResponse(authentication.getName(), true);
    }

    @GetMapping("/me")
    public AuthDtos.AuthResponse me(Authentication authentication) {
        return new AuthDtos.AuthResponse(authentication.getName(), true);
    }

    @GetMapping("/csrf")
    public AuthDtos.CsrfResponse csrf(CsrfToken token) {
        // 返回 Spring 生成的掩码令牌；前端不能直接把 Cookie 中的原始值当作请求头。
        return new AuthDtos.CsrfResponse(token.getToken(), token.getHeaderName());
    }
}


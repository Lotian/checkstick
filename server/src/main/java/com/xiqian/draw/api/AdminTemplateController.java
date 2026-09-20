package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.TemplateDtos;
import com.xiqian.draw.service.RoleTemplateService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/role-templates")
public class AdminTemplateController {

    private final RoleTemplateService service;

    public AdminTemplateController(RoleTemplateService service) {
        this.service = service;
    }

    @GetMapping
    public List<TemplateDtos.TemplateResponse> list() {
        return service.list();
    }

    @PutMapping
    public List<TemplateDtos.TemplateResponse> update(
            @Valid @RequestBody TemplateDtos.UpdateTemplatesRequest request) {
        return service.update(request);
    }
}


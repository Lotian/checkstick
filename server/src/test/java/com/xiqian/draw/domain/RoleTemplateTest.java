package com.xiqian.draw.domain;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

class RoleTemplateTest {

    @Test
    void shouldAllowVillagerTaskToBeConfigured() {
        RoleTemplate template = new RoleTemplate();
        ReflectionTestUtils.setField(template, "roleType", RoleType.VILLAGER);

        template.update("  找到一位村民交换线索  ", "  领取参与礼  ");

        assertThat(template.getTaskText()).isEqualTo("找到一位村民交换线索");
        assertThat(template.getRewardText()).isEqualTo("领取参与礼");
    }
}

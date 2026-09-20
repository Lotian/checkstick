package com.xiqian.draw.service;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class GroupCodeGeneratorTest {

    @Test
    void shouldGenerateFourDigitCodes() {
        GroupCodeGenerator generator = new GroupCodeGenerator();
        Set<String> codes = new HashSet<>();
        StringBuilder everyDigit = new StringBuilder();

        for (int i = 0; i < 200; i++) {
            String code = generator.nextCode();
            assertThat(code).matches("\\d{4}");
            codes.add(code);
            everyDigit.append(code);
        }

        // 一万个码位里抽 200 次，理论重复约 2 个，这里留足余量
        assertThat(codes).hasSizeGreaterThan(180);

        // 十种数字都应出现过（缺任何一种的概率极低，不构成偶发失败）
        String digits = everyDigit.toString();
        for (char digit = '0'; digit <= '9'; digit++) {
            assertThat(digits).contains(String.valueOf(digit));
        }
    }
}

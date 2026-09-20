package com.xiqian.draw;

import com.xiqian.draw.config.AppProperties;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AppPropertiesTest {

    @Test
    void shouldReturnEmptyWhenPlayerBaseUrlNotConfigured() {
        assertThat(new AppProperties().resolvePlayerBaseUrl()).isEmpty();
    }

    @Test
    void shouldNormalizePlayerBaseUrlWithSingleTrailingSlash() {
        AppProperties properties = new AppProperties();
        properties.setPublicBaseUrl("  https://h5.example.com  ");
        assertThat(properties.resolvePlayerBaseUrl()).isEqualTo("https://h5.example.com/");
        properties.setPublicBaseUrl("https://h5.example.com/");
        assertThat(properties.resolvePlayerBaseUrl()).isEqualTo("https://h5.example.com/");
    }

    @Test
    void shouldRejectBlankAdminCredentialsConfiguration() {
        AppProperties properties = new AppProperties();
        assertThat(properties.getAdmin().getUsername()).isEmpty();
        assertThat(properties.getAdmin().getPassword()).isEmpty();
    }
}

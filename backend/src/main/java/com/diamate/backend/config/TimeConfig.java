package com.diamate.backend.config;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Provides "now" as a bean, so rules that depend on the date (e.g. the minimum registration age)
 * can be tested with a fixed date instead of the real clock.
 */
@Configuration
public class TimeConfig {

    @Bean
    public Clock clock() {
        return Clock.systemDefaultZone();
    }
    
}
package com.diamate.backend.config;

import java.time.Clock;
import java.time.ZoneId;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Provides "now" as a bean, so rules that depend on the date (e.g. the minimum registration age)
 * can be tested with a fixed date instead of the real clock.
 */
@Configuration // This class contains recipes for Spring to create objects.
public class TimeConfig {

    @Bean // Put the object returned by this method into a container and give it to anyone who wants it.
    public Clock clock() {
        return Clock.system(ZoneId.of("Europe/Istanbul")); // Permanently based in Istanbul
    }
    
}
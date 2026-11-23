package com.diamate.backend.config;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;

import org.springframework.context.annotation.Configuration;
import org.springframework.format.Formatter;
import org.springframework.format.FormatterRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Times in the query string (?from=, ?to=) are ISO-8601 text only, the same rule as in request bodies
 * (StrictInstantDeserializer). Spring's default reads a plain number as milliseconds since 1970, so ?from=0 meant
 * 1970-01-01 and ?from=2026 a moment in 1970 as well (QA scan, week 3). Any other text is a 400 with the parameter's
 * name. "+03:00" in a URL must be sent as "%2B03:00".
 */
@Configuration
public class StrictInstantFormatConfig implements WebMvcConfigurer {

    @Override
    public void addFormatters(FormatterRegistry registry) {
        registry.addFormatterForFieldType(Instant.class, new IsoInstantFormatter());
    }

    static final class IsoInstantFormatter implements Formatter<Instant> {

        @Override
        public Instant parse(String text, Locale locale) {
            try {
                return OffsetDateTime.parse(text.trim(), DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant();
            } catch (DateTimeParseException e) {
                throw new IllegalArgumentException("Must be an ISO-8601 date-time, e.g. 2026-10-05T08:30:00Z", e);
            }
        }

        @Override
        public String print(Instant instant, Locale locale) {
            return instant.toString();
        }
    }
}

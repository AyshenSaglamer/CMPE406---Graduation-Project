package com.diamate.backend.config;

import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import tools.jackson.databind.cfg.CoercionAction;
import tools.jackson.databind.cfg.CoercionInputShape;

/**
 * Empty or blank text is not a value for a number, a true/false, a UUID or an enum: "carbsG": " " or
 * "canViewMeals": "" was silently read as null (for a permission: "leave unchanged") instead of an error (QA scan,
 * week 3). Now it is a 400 with errors.<field>. Text fields are not affected ("" stays an empty text, then the field's
 * own rules apply), and JSON null is still null.
 *
 * The other strictness rules are in application.yml (spring.jackson.*), StrictInstantDeserializer and
 * TextDeserializer.
 */
@Configuration
public class JsonStrictnessConfig {

    @Bean
    JsonMapperBuilderCustomizer noEmptyStringAsNull() {
        return builder -> builder.withCoercionConfigDefaults(config -> config
                .setAcceptBlankAsEmpty(false)
                .setCoercion(CoercionInputShape.EmptyString, CoercionAction.Fail));
    }
}

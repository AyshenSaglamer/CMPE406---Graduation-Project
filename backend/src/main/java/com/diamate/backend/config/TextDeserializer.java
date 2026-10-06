package com.diamate.backend.config;

import org.springframework.boot.jackson.JacksonComponent;

import tools.jackson.core.JsonParser;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.deser.jdk.StringDeserializer;
import tools.jackson.databind.deser.std.StdScalarDeserializer;

/**
 * Every text value of a JSON request body goes through here (Spring Boot registers @JacksonComponent classes with
 * the JSON mapper). Control characters are refused with 400: the NUL character (code 0) cannot be stored in
 * PostgreSQL at all and caused a 500, and the others are invisible junk in a name, an email or a note.
 * Line breaks and tabs are allowed, because notes may have several lines.
 */
@JacksonComponent
public class TextDeserializer extends StdScalarDeserializer<String> {

    public static final String CONTROL_CHARACTER_MESSAGE = "Must not contain control characters";

    public TextDeserializer() {
        super(String.class);
    }

    @Override
    public String deserialize(JsonParser parser, DeserializationContext context) {
        // Jackson's own text handling first (e.g. 42 -> "42"), then the extra check.
        String value = StringDeserializer.instance.deserialize(parser, context);
        if (value != null && containsControlCharacter(value)) {
            // Becomes a 400 with errors.<field> in GlobalExceptionHandler.
            return (String) context.handleWeirdStringValue(String.class, value, "contains control characters");
        }
        return value;
    }

    static boolean containsControlCharacter(String value) {
        return value.chars().anyMatch(c -> Character.isISOControl(c) && c != '\t' && c != '\n' && c != '\r');
    }
}

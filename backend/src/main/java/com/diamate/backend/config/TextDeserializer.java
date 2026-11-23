package com.diamate.backend.config;

import org.springframework.boot.jackson.JacksonComponent;

import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.deser.jdk.StringDeserializer;
import tools.jackson.databind.deser.std.StdScalarDeserializer;

/**
 * Every text value of a JSON request body goes through here (Spring Boot registers @JacksonComponent classes with
 * the JSON mapper). Control characters are refused with 400: the NUL character (code 0) cannot be stored in
 * PostgreSQL at all and caused a 500, and the others are invisible junk in a name, an email or a note.
 * Line breaks and tabs are allowed, because notes may have several lines.
 *
 * Numbers and booleans are not turned into text (Jackson would make 42 into "42" and true into "true"). JSON null
 * never reaches a deserializer, so an optional text field can still be null.
 */
@JacksonComponent
public class TextDeserializer extends StdScalarDeserializer<String> {

    public static final String CONTROL_CHARACTER_MESSAGE = "Must not contain control characters";

    public TextDeserializer() {
        super(String.class);
    }

    @Override
    public String deserialize(JsonParser parser, DeserializationContext context) {
        // Only a JSON string is text: 42 or true sent for a note or a name is a 400 ("Must be text"), not "42".
        if (!parser.hasToken(JsonToken.VALUE_STRING)) {
            return (String) context.handleUnexpectedToken(String.class, parser);
        }
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

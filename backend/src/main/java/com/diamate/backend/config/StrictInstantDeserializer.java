package com.diamate.backend.config;

import java.time.Instant;

import org.springframework.boot.jackson.JacksonComponent;

import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.ext.javatime.deser.InstantDeserializer;
import tools.jackson.databind.deser.std.StdScalarDeserializer;

/**
 * Times in a JSON request body are ISO-8601 text only ("2026-10-05T08:30:00Z", "2026-10-05T11:30:00+03:00").
 * Jackson would also read a number as seconds since 1970, so {"measurementTime": 0} was saved as 1970-01-01 and a
 * millisecond timestamp from a buggy client as a date thousands of years away (QA scan, week 3). A number is now a 400
 * with errors.<field> "Must be an ISO-8601 date-time ...". The text itself is still parsed by Jackson's own reader.
 */
@JacksonComponent
public class StrictInstantDeserializer extends StdScalarDeserializer<Instant> {

    public StrictInstantDeserializer() {
        super(Instant.class);
    }

    @Override
    public Instant deserialize(JsonParser parser, DeserializationContext context) {
        if (!parser.hasToken(JsonToken.VALUE_STRING)) {
            return (Instant) context.handleUnexpectedToken(Instant.class, parser);
        }
        return InstantDeserializer.INSTANT.deserialize(parser, context);
    }
}

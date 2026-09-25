package com.diamate.backend.dto;

public class AiParseRequest {

    private String text;

    public AiParseRequest() {
    }

    public AiParseRequest(String text) {
        this.text = text;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }
}

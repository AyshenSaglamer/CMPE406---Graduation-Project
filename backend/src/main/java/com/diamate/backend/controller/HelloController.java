package com.diamate.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String home() {
        return "DiaMate Backend calisiyor!";
    }

    @GetMapping("/api/hello")
    public String hello() {
        return "Nginx Spring Boot'a basariyla baglandi!";
    }

    @GetMapping("/api/health")
    public String health() {
        return "OK";
    }
}

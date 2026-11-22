package com.diamate.backend.ai;

import java.time.Duration;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/** The HTTP client used to call the AI service, with its address and timeouts from AiProperties. */
@Configuration
@EnableConfigurationProperties(AiProperties.class)
public class AiClientConfig {

    @Bean
    public RestClient aiRestClient(AiProperties properties) {
        return client(properties, properties.readTimeout());
    }

    /** Same service, longer read timeout: speech-to-text of a recording takes longer than parsing text. */
    @Bean
    public RestClient aiVoiceRestClient(AiProperties properties) {
        return client(properties, properties.voiceReadTimeout());
    }

    private static RestClient client(AiProperties properties, Duration readTimeout) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(properties.connectTimeout());
        requestFactory.setReadTimeout(readTimeout);
        return RestClient.builder()
                .baseUrl(properties.baseUrl())
                .requestFactory(requestFactory)
                .build();
    }
}

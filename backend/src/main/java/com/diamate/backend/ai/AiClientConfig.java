package com.diamate.backend.ai;

import java.time.Duration;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * The HTTP clients used to call the AI service (AiProperties) and the food photo service (FoodVisionProperties), with
 * their addresses and timeouts.
 */
@Configuration
@EnableConfigurationProperties({ AiProperties.class, FoodVisionProperties.class })
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

    @Bean
    public RestClient foodVisionRestClient(FoodVisionProperties properties) {
        return client(properties.baseUrl(), properties.connectTimeout(), properties.readTimeout());
    }

    private static RestClient client(AiProperties properties, Duration readTimeout) {
        return client(properties.baseUrl(), properties.connectTimeout(), readTimeout);
    }

    private static RestClient client(String baseUrl, Duration connectTimeout, Duration readTimeout) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(connectTimeout);
        requestFactory.setReadTimeout(readTimeout);
        return RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(requestFactory)
                .build();
    }
}

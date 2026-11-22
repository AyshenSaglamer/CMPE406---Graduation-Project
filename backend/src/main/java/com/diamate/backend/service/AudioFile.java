package com.diamate.backend.service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.exception.InvalidFieldException;

/**
 * A voice recording checked before it is sent to the AI service, with the same rules as ai-service's
 * validate_audio_upload: WAV, MP3, M4A, WEBM or OGG, not empty, at most 10 MB. Problems are a 400 with errors.audio.
 *
 * The file type is decided by the extension: phones often send application/octet-stream. A declared type that is
 * clearly something else (an image, a PDF ...) is refused. The AI service gets a fixed name ("recording.m4a"), never
 * the name chosen by the client.
 */
record AudioFile(byte[] bytes, String filename, MediaType contentType) {

    static final long MAX_BYTES = 10L * 1024 * 1024;

    static final Map<String, MediaType> TYPES = Map.of(
            ".wav", MediaType.parseMediaType("audio/wav"),
            ".mp3", MediaType.parseMediaType("audio/mpeg"),
            ".m4a", MediaType.parseMediaType("audio/mp4"),
            ".webm", MediaType.parseMediaType("audio/webm"),
            ".ogg", MediaType.parseMediaType("audio/ogg"));

    /** Declared types that are accepted besides audio/*: generic uploads and WEBM recorded by a browser. */
    private static final Set<String> ALSO_ACCEPTED = Set.of("application/octet-stream", "video/webm");

    static AudioFile check(MultipartFile audio) {
        if (audio == null || audio.isEmpty()) {
            throw new InvalidFieldException("audio", "An audio recording is required");
        }
        if (audio.getSize() > MAX_BYTES) {
            throw new InvalidFieldException("audio", "The recording must be at most 10 MB");
        }
        String name = audio.getOriginalFilename() == null ? "" : audio.getOriginalFilename().toLowerCase(Locale.ROOT);
        String extension = name.contains(".") ? name.substring(name.lastIndexOf('.')) : "";
        MediaType type = TYPES.get(extension);
        if (type == null) {
            throw new InvalidFieldException("audio", "The recording must be a WAV, MP3, M4A, WEBM or OGG file");
        }
        String declared = audio.getContentType() == null ? "" : audio.getContentType().toLowerCase(Locale.ROOT);
        String declaredType = declared.split(";", 2)[0].strip();
        if (!declaredType.isEmpty() && !declaredType.startsWith("audio/") && !ALSO_ACCEPTED.contains(declaredType)) {
            throw new InvalidFieldException("audio", "The recording must be a WAV, MP3, M4A, WEBM or OGG file");
        }
        try {
            return new AudioFile(audio.getBytes(), "recording" + extension, type);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}

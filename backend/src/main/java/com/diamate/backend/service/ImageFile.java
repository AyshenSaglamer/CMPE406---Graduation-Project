package com.diamate.backend.service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Arrays;
import java.util.Iterator;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;

import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.exception.InvalidFieldException;

/**
 * A meal photo checked before it is sent to the food photo service, with the same rules as its /predict-food: JPG,
 * PNG or WEBP, not empty, at most 5 MB. Problems are a 400 with errors.image.
 *
 * The type is decided by the first bytes of the file, not by its name or declared type (phones often send
 * application/octet-stream, and a name says nothing about the content). For JPG and PNG the width and height are
 * read from the header without decoding the picture: a small file can declare a huge picture that would take
 * gigabytes of memory to decode ("decompression bomb"), so more than MAX_PIXELS is refused here.
 *
 * The service gets a fixed name ("meal.jpg"), never the name chosen by the client. Nothing is written to disk.
 */
record ImageFile(byte[] bytes, String filename, MediaType contentType) {

    static final long MAX_BYTES = 5L * 1024 * 1024;

    /** 50 megapixels: more than any phone camera's normal photo, far below Pillow's own bomb limit (179 MP). */
    static final long MAX_PIXELS = 50_000_000L;

    static final String WRONG_TYPE = "The image must be a JPG, PNG or WEBP file";

    private static final byte[] JPEG = { (byte) 0xFF, (byte) 0xD8, (byte) 0xFF };
    private static final byte[] PNG = { (byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' };
    private static final byte[] RIFF = { 'R', 'I', 'F', 'F' };
    private static final byte[] WEBP = { 'W', 'E', 'B', 'P' };

    static ImageFile check(MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new InvalidFieldException("image", "An image is required");
        }
        if (image.getSize() > MAX_BYTES) {
            throw new InvalidFieldException("image", "The image must be at most 5 MB");
        }
        byte[] bytes;
        try {
            bytes = image.getBytes();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        if (startsWith(bytes, 0, JPEG)) {
            checkPixels(bytes);
            return new ImageFile(bytes, "meal.jpg", MediaType.IMAGE_JPEG);
        }
        if (startsWith(bytes, 0, PNG)) {
            checkPixels(bytes);
            return new ImageFile(bytes, "meal.png", MediaType.IMAGE_PNG);
        }
        if (startsWith(bytes, 0, RIFF) && startsWith(bytes, 8, WEBP)) {
            // Java cannot read WEBP headers; the service's Pillow refuses pictures over its own limit.
            return new ImageFile(bytes, "meal.webp", MediaType.parseMediaType("image/webp"));
        }
        throw new InvalidFieldException("image", WRONG_TYPE);
    }

    /** Width x height from the header only (ImageReader.getWidth does not decode the pixels). */
    private static void checkPixels(byte[] bytes) {
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
            Iterator<ImageReader> readers = input == null ? null : ImageIO.getImageReaders(input);
            if (readers == null || !readers.hasNext()) {
                throw new InvalidFieldException("image", WRONG_TYPE);
            }
            ImageReader reader = readers.next();
            try {
                reader.setInput(input, true, true);
                long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
                if (pixels <= 0) {
                    throw new InvalidFieldException("image", "The image could not be read");
                }
                if (pixels > MAX_PIXELS) {
                    throw new InvalidFieldException("image", "The image must be at most 50 megapixels");
                }
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException e) {
            if (e instanceof InvalidFieldException invalid) {
                throw invalid;
            }
            // A cut or damaged header (IIOException, IndexOutOfBounds ... from the readers).
            throw new InvalidFieldException("image", "The image could not be read");
        }
    }

    private static boolean startsWith(byte[] bytes, int offset, byte[] prefix) {
        return bytes.length >= offset + prefix.length
                && Arrays.equals(bytes, offset, offset + prefix.length, prefix, 0, prefix.length);
    }
}

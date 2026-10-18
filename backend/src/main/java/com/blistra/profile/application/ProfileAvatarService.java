package com.blistra.profile.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.documents.storage.DocumentStorageService;
import com.blistra.documents.storage.DocumentTooLargeException;
import com.blistra.profile.dto.ProfileResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserProfile;
import com.blistra.users.repository.UserProfileRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Profile photo upload/read/remove. Photos reuse the document storage
 * backend (server-generated UUID keys) and are only served to their owner.
 * The type is decided from the file's magic bytes, never the client's
 * declared content type.
 */
@Slf4j
@Service
public class ProfileAvatarService {

    public static final long MAX_AVATAR_BYTES = 5L * 1024 * 1024;

    private final CurrentUserProvider currentUserProvider;
    private final UserProfileRepository profileRepository;
    private final DocumentStorageService storage;
    private final com.blistra.users.repository.UserRepository users;

    public ProfileAvatarService(CurrentUserProvider currentUserProvider,
                                UserProfileRepository profileRepository,
                                DocumentStorageService storage,com.blistra.users.repository.UserRepository users) {
        this.currentUserProvider = currentUserProvider;
        this.profileRepository = profileRepository;
        this.storage = storage;
        this.users = users;
    }

    public record Avatar(Resource resource, String contentType) {}

    @Transactional
    public ProfileResponse upload(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Choose a photo to upload.");
        }
        if (file.getSize() > MAX_AVATAR_BYTES) {
            throw new BadRequestException("Photo must be 5 MB or smaller.");
        }
        String contentType = detectImageType(file);
        User user = currentUserProvider.getCurrentUser();
        users.lockById(user.getId()).orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        UserProfile profile = profileFor(user.getId());

        String key = UUID.randomUUID().toString();
        try (InputStream in = file.getInputStream()) {
            storage.store(key, in, MAX_AVATAR_BYTES);
        } catch (DocumentTooLargeException e) {
            throw new BadRequestException("Photo must be 5 MB or smaller.");
        } catch (IOException e) {
            throw new BadRequestException("Could not read the uploaded photo.");
        }

        String previous = profile.getAvatarObjectKey();
        profile.setAvatarObjectKey(key);
        profile.setAvatarContentType(contentType);
        profile.setAvatarUpdatedAt(LocalDateTime.now());
        profileRepository.save(profile);
        deleteQuietly(previous);
        return ProfileService.toResponse(user, profile);
    }

    @Transactional(readOnly = true)
    public Avatar load() {
        User user = currentUserProvider.getCurrentUser();
        UserProfile profile = profileRepository.findByUserId(user.getId())
                .filter(p -> p.getAvatarObjectKey() != null)
                .orElseThrow(() -> new ResourceNotFoundException("No profile photo"));
        return new Avatar(storage.load(profile.getAvatarObjectKey()),
                profile.getAvatarContentType());
    }

    @Transactional
    public ProfileResponse remove() {
        User user = currentUserProvider.getCurrentUser();
        users.lockById(user.getId()).orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        UserProfile profile = profileFor(user.getId());
        String previous = profile.getAvatarObjectKey();
        profile.setAvatarObjectKey(null);
        profile.setAvatarContentType(null);
        profile.setAvatarUpdatedAt(null);
        profileRepository.save(profile);
        deleteQuietly(previous);
        return ProfileService.toResponse(user, profile);
    }

    private UserProfile profileFor(UUID userId) {
        return profileRepository.findByUserId(userId)
                .orElseGet(() -> profileRepository.save(new UserProfile(userId)));
    }

    private void deleteQuietly(String key) {
        if (key == null) return;
        try {
            storage.delete(key);
        } catch (RuntimeException e) {
            log.warn("Could not delete old profile photo {}", key, e);
        }
    }

    /** JPEG, PNG or WebP by magic bytes; anything else is rejected. */
    static String detectImageType(MultipartFile file) {
        byte[] head = new byte[12];
        int read;
        try (InputStream in = file.getInputStream()) {
            read = in.readNBytes(head, 0, head.length);
        } catch (IOException e) {
            throw new BadRequestException("Could not read the uploaded photo.");
        }
        if (read >= 3 && (head[0] & 0xFF) == 0xFF && (head[1] & 0xFF) == 0xD8
                && (head[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (read >= 8 && (head[0] & 0xFF) == 0x89 && head[1] == 'P' && head[2] == 'N'
                && head[3] == 'G') {
            return "image/png";
        }
        if (read >= 12 && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P') {
            return "image/webp";
        }
        throw new BadRequestException("Photo must be a JPEG, PNG or WebP image.");
    }
}

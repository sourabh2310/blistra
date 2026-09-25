package com.blistra.preferences.repository;

import com.blistra.preferences.domain.UserAppPreferences;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserAppPreferencesRepository extends JpaRepository<UserAppPreferences, UUID> {
}

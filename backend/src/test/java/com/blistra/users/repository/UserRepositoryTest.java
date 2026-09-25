package com.blistra.users.repository;

import com.blistra.AbstractIntegrationTest;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void testSaveAndRetrieveUser() {
        User user = new User("test@example.com", "hashed_password");
        user.setUsername("testuser");
        User savedUser = userRepository.save(user);

        assertThat(savedUser.getId()).isNotNull();
        assertThat(savedUser.getEmail()).isEqualTo("test@example.com");
        assertThat(savedUser.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    void testFindByEmailSuccess() {
        User user = new User("test@example.com", "hashed_password");
        user.setUsername("testuser");
        userRepository.save(user);

        Optional<User> foundUser = userRepository.findByEmail("test@example.com");

        assertThat(foundUser).isPresent();
        assertThat(foundUser.get().getEmail()).isEqualTo("test@example.com");
    }

    @Test
    void testFindByEmailNotFound() {
        Optional<User> foundUser = userRepository.findByEmail("nonexistent@example.com");

        assertThat(foundUser).isEmpty();
    }

    @Test
    void testUniqueEmailConstraint() {
        User user1 = new User("test@example.com", "hashed_password1");
        user1.setUsername("testuser");
        userRepository.save(user1);

        User user2 = new User("test@example.com", "hashed_password2");
        user2.setUsername("testuser");

        assertThatThrownBy(() -> userRepository.save(user2))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void testExistsByEmail() {
        User user = new User("test@example.com", "hashed_password");
        user.setUsername("testuser");
        userRepository.save(user);

        assertThat(userRepository.existsByEmail("test@example.com")).isTrue();
        assertThat(userRepository.existsByEmail("nonexistent@example.com")).isFalse();
    }

    @Test
    void testUserStatusDefault() {
        User user = new User("test@example.com", "hashed_password");
        user.setUsername("testuser");
        User savedUser = userRepository.save(user);

        assertThat(savedUser.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }
}

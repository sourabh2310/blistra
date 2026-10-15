package com.blistra.auth.otp;

import com.blistra.common.exception.VerificationUnavailableException;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;

import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class SmtpEmailSenderTest {

    private final JavaMailSender mailSender = mock(JavaMailSender.class);
    private final SmtpEmailSender sender = new SmtpEmailSender(
            mailSender, "no-reply@blistra.app", "Blistra", otpProperties());

    private static OtpProperties otpProperties() {
        OtpProperties properties = new OtpProperties();
        properties.setDevMode(true);
        properties.setTtlMinutes(10);
        return properties;
    }

    private MimeMessage newMessage() {
        return new MimeMessage(Session.getInstance(new Properties()));
    }

    @Test
    void sendsMessageWithCodeToRecipient() throws Exception {
        when(mailSender.createMimeMessage()).thenReturn(newMessage());

        sender.sendVerificationCode("user@example.com", "123456");

        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender).send(captor.capture());
        MimeMessage sent = captor.getValue();
        assertThat(sent.getAllRecipients()[0].toString()).isEqualTo("user@example.com");
        assertThat(sent.getSubject()).contains("123456");
    }

    @Test
    void providerFailureBecomesVerificationUnavailable() {
        when(mailSender.createMimeMessage()).thenReturn(newMessage());
        doThrow(new MailSendException("smtp down")).when(mailSender).send(any(MimeMessage.class));

        assertThatThrownBy(() -> sender.sendVerificationCode("user@example.com", "123456"))
                .isInstanceOf(VerificationUnavailableException.class)
                .hasMessageNotContaining("123456")
                .hasMessageNotContaining("user@example.com");
    }
}

package com.blistra.auth.otp;

import com.blistra.common.exception.VerificationUnavailableException;
import jakarta.mail.internet.MimeMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;

/**
 * Sends verification codes over SMTP (Brevo, Gmail, any provider). Active when
 * {@code blistra.mail.enabled=true}; connection settings come from the standard
 * {@code spring.mail.*} properties. Codes are never logged.
 */
@Slf4j
@Component
@ConditionalOnProperty(prefix = "blistra.mail", name = "enabled", havingValue = "true")
public class SmtpEmailSender implements EmailSender {

    private final JavaMailSender mailSender;
    private final String from;
    private final String appName;
    private final int ttlMinutes;

    public SmtpEmailSender(JavaMailSender mailSender,
                           @Value("${blistra.mail.from}") String from,
                           @Value("${blistra.mail.app-name:Blistra}") String appName,
                           OtpProperties otpProperties) {
        this.mailSender = mailSender;
        this.from = from;
        this.appName = appName;
        this.ttlMinutes = otpProperties.getTtlMinutes();
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(from, appName);
            helper.setTo(toEmail);
            helper.setSubject(appName + " verification code: " + code);
            helper.setText(plainText(code), htmlText(code));
            mailSender.send(message);
        } catch (Exception e) {
            // Log the failure type only: never the code or the address.
            log.error("Verification email could not be sent ({})", e.getClass().getSimpleName());
            throw new VerificationUnavailableException(
                    "We could not send the verification email. Please try again later.");
        }
    }

    private String plainText(String code) {
        return "Your " + appName + " verification code is " + code + ".\n\n"
                + "It expires in " + ttlMinutes + " minutes. If you did not request it, ignore this email.";
    }

    private String htmlText(String code) {
        return "<div style=\"font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px\">"
                + "<h2 style=\"margin:0 0 8px\">" + appName + "</h2>"
                + "<p>Your verification code is</p>"
                + "<p style=\"font-size:32px;letter-spacing:8px;font-weight:bold;margin:12px 0\">" + code + "</p>"
                + "<p style=\"color:#666\">It expires in " + ttlMinutes
                + " minutes. If you did not request it, ignore this email.</p></div>";
    }
}

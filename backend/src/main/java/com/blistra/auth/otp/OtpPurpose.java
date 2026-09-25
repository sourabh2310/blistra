package com.blistra.auth.otp;

/** Why an OTP was issued. Stored on the record; drives verification effects. */
public enum OtpPurpose {
    EMAIL_VERIFY,
    PHONE_VERIFY,
    PASSWORD_RESET,
    EMAIL_CHANGE,
    PHONE_CHANGE
}

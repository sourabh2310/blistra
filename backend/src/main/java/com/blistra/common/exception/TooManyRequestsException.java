package com.blistra.common.exception;

/** Hourly issuance cap hit (429). Message stays generic. */
public class TooManyRequestsException extends RuntimeException {
    public TooManyRequestsException(String message) {
        super(message);
    }
}

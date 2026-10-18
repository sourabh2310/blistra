package com.blistra.ai;

public class AiUnavailableException extends RuntimeException {
    public AiUnavailableException() {
        super("Blistra AI is unavailable. Please try again later or use the app modules directly.");
    }
}

package com.blistra.documents.storage;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
public class StorageCapacityException extends RuntimeException {
    public StorageCapacityException() { super("Upload storage is at capacity. Please try again later."); }
}

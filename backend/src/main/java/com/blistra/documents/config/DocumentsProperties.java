package com.blistra.documents.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.unit.DataSize;

import java.nio.file.Path;

@ConfigurationProperties(prefix = "blistra.documents")
public record DocumentsProperties(
        Path storageRoot,
        DataSize maxFileSize
) {}
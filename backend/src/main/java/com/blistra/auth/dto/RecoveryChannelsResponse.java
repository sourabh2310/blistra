package com.blistra.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Verified recovery destinations for an identifier. Only verified channels
 * are listed; destinations are masked (no full email/phone, no user id).
 * An empty channel list means the account exists but has no verified
 * recovery destination.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecoveryChannelsResponse {
    /** Subset of EMAIL/SMS, verified only. */
    private List<String> channels;
    /** Masked email (s***@domain) when EMAIL is offered, else null. */
    private String emailMasked;
    /** Masked phone (***10) when SMS is offered, else null. */
    private String phoneMasked;
}

package com.blistra.finance.domain;

/** How an expense is divided between its participants. */
public enum SplitType {
    /** Personal expense: the creator paid and owes all of it. */
    NONE,
    /** Divided equally; leftover cents go to the first participants. */
    EQUAL,
    /** Each participant's amount is given explicitly and must sum to the total. */
    EXACT,
    /** Each participant's percentage is given and must sum to 100. */
    PERCENT,
    /** Divided proportionally to positive share weights. */
    SHARES
}

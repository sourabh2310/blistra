package com.blistra.finance.domain;

/**
 * Fixed expense categories. A fixed set (rather than per-user categories)
 * lets an expense shared between friends mean the same thing to everyone
 * and lets an expense be logged without any setup.
 */
public enum ExpenseCategory {
    FOOD,
    GROCERIES,
    TRANSPORT,
    FUEL,
    SHOPPING,
    BILLS,
    RENT,
    ENTERTAINMENT,
    TRAVEL,
    HEALTH,
    EDUCATION,
    GIFTS,
    PERSONAL_CARE,
    SUBSCRIPTIONS,
    OTHER
}

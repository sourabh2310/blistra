/// Shared navigation/widget identifiers for Home + bottom navigation.
///
/// Single source of truth used by the shell, Home, Hub, customization
/// screens and the persisted preferences controller. Identifiers are the
/// canonical backend tokens (uppercase); the backend rejects anything else.
library;

import 'dart:collection';

import 'package:flutter/material.dart';

/// Bottom-navigation destinations. HOME and ADD are mandatory; HUB keeps
/// every module reachable when unpinned via the Home surface.
abstract final class ShellDestinations {
  static const String home = 'HOME';
  static const String planner = 'PLANNER';
  static const String add = 'ADD';
  static const String health = 'HEALTH';
  static const String medicines = 'MEDICINES';
  static const String diet = 'DIET';
  static const String habits = 'HABITS';
  static const String finance = 'FINANCE';
  static const String hub = 'HUB';

  static const List<String> allowed = [
    home,
    planner,
    add,
    health,
    medicines,
    diet,
    habits,
    finance,
    hub,
  ];

  static const List<String> defaults = [home, planner, add, health, hub];

  static const int maxItems = 5;

  static String label(String id) => switch (id) {
        home => 'Home',
        planner => 'Planner',
        add => 'Add',
        health => 'Health',
        medicines => 'Medicines',
        diet => 'Diet',
        habits => 'Habits',
        finance => 'Finance',
        hub => 'Hub',
        _ => id,
      };

  static IconData icon(String id) => switch (id) {
        home => Icons.home_outlined,
        planner => Icons.calendar_today_outlined,
        health => Icons.favorite_outline,
        medicines => Icons.medication_outlined,
        diet => Icons.restaurant_outlined,
        habits => Icons.check_circle_outline,
        finance => Icons.account_balance_wallet_outlined,
        hub => Icons.grid_view_outlined,
        _ => Icons.circle_outlined,
      };

  static IconData selectedIcon(String id) => switch (id) {
        home => Icons.home,
        planner => Icons.calendar_today,
        health => Icons.favorite,
        medicines => Icons.medication,
        diet => Icons.restaurant,
        habits => Icons.check_circle,
        finance => Icons.account_balance_wallet,
        hub => Icons.grid_view_rounded,
        _ => Icons.circle,
      };

  /// Client-side mirror of the backend rules (backend re-validates).
  static List<String> normalizeNav(List<String> raw) {
    final cleaned = [
      for (final item in raw)
        item.trim().toUpperCase(),
    ].where((id) => id.isNotEmpty).toList();
    for (final id in cleaned) {
      if (!allowed.contains(id)) {
        throw ArgumentError('Unknown navigation destination: $id');
      }
    }
    if (!cleaned.contains(home)) {
      throw ArgumentError('HOME cannot be removed from navigation');
    }
    if (!cleaned.contains(add)) {
      throw ArgumentError('ADD cannot be removed from navigation');
    }
    if (cleaned.length > maxItems) {
      throw ArgumentError('At most $maxItems navigation items allowed');
    }
    return LinkedHashSet<String>.from(cleaned).toList();
  }
}

/// Reorderable Home widgets. DAY_AT_A_GLANCE is the locked hero.
abstract final class HomeWidgets {
  static const String dayAtAGlance = 'DAY_AT_A_GLANCE';
  static const String health = 'HEALTH';
  static const String medicines = 'MEDICINES';
  static const String diet = 'DIET';
  static const String habits = 'HABITS';
  static const String planner = 'PLANNER';
  static const String finance = 'FINANCE';

  static const List<String> allowed = [
    dayAtAGlance,
    health,
    medicines,
    diet,
    habits,
    planner,
    finance,
  ];

  static const List<String> defaults = [
    dayAtAGlance,
    health,
    medicines,
    diet,
    habits,
    planner,
    finance,
  ];

  static String label(String id) => switch (id) {
        dayAtAGlance => 'Day at a glance',
        health => 'Health',
        medicines => 'Medicines',
        diet => 'Diet',
        habits => 'Habits',
        planner => 'Planner',
        finance => 'Finance',
        _ => id,
      };

  /// Client-side mirror of the backend rules (backend re-validates).
  static List<String> normalizeWidgets(List<String> raw) {
    final cleaned = [
      for (final item in raw)
        item.trim().toUpperCase(),
    ].where((id) => id.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      throw ArgumentError('homeWidgets must not be empty');
    }
    for (final id in cleaned) {
      if (!allowed.contains(id)) {
        throw ArgumentError('Unknown home widget: $id');
      }
    }
    final ordered = LinkedHashSet<String>()..add(dayAtAGlance);
    ordered.addAll(cleaned);
    return ordered.toList();
  }
}

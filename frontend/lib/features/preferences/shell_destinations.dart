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

  static const List<String> defaults = [home, planner, add, hub, health];

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
    if (cleaned.toSet().length != cleaned.length) {
      throw ArgumentError('Navigation destinations cannot be duplicated');
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
    final optional = [
      for (final id in LinkedHashSet<String>.from(cleaned))
        if (id != home && id != add) id,
    ];
    final before = ((optional.length - 1) ~/ 2).clamp(0, optional.length).toInt();
    return [
      home,
      ...optional.take(before),
      add,
      ...optional.skip(before),
    ];
  }
}

/// Reorderable Home content. Section tokens and module tokens share the
/// persisted list so older preference clients remain compatible.
abstract final class HomeWidgets {
  static const String todayOverview = 'TODAY_OVERVIEW';
  static const String todaysSchedule = 'TODAYS_SCHEDULE';
  static const String needsAttention = 'NEEDS_ATTENTION';
  static const String yourLife = 'YOUR_LIFE';
  static const String thisWeek = 'THIS_WEEK';
  static const String health = 'HEALTH';
  static const String medicines = 'MEDICINES';
  static const String diet = 'DIET';
  static const String habits = 'HABITS';
  static const String finance = 'FINANCE';

  static const String legacyOverview = 'DAY_AT_A_GLANCE';
  static const String legacyPlanner = 'PLANNER';

  static const List<String> sections = [
    todayOverview,
    todaysSchedule,
    needsAttention,
    yourLife,
    thisWeek,
  ];
  static const List<String> modules = [
    health,
    medicines,
    diet,
    habits,
    finance,
  ];
  static const List<String> allowed = [...sections, ...modules];
  static const List<String> defaults = [...sections, ...modules];

  static String label(String id) => switch (id) {
        todayOverview => 'Today overview',
        todaysSchedule => "Today's schedule",
        needsAttention => 'Needs attention',
        yourLife => 'Your life',
        thisWeek => 'This week',
        health => 'Health',
        medicines => 'Medicines',
        diet => 'Diet',
        habits => 'Habits',
        finance => 'Finance',
        _ => id,
      };

  static String canonical(String id) => switch (id) {
        legacyOverview => todayOverview,
        legacyPlanner => todaysSchedule,
        _ => id,
      };

  static List<String> normalizeWidgets(List<String> raw) {
    final cleaned = <String>[];
    for (final item in raw) {
      final id = canonical(item.trim().toUpperCase());
      if (id.isEmpty || cleaned.contains(id)) {
        continue;
      }
      if (!allowed.contains(id)) {
        throw ArgumentError('Unknown home widget: $id');
      }
      cleaned.add(id);
    }
    if (cleaned.isEmpty) {
      throw ArgumentError('homeWidgets must not be empty');
    }
    if (cleaned.any(modules.contains) && !cleaned.contains(yourLife)) {
      cleaned.add(yourLife);
    }
    return cleaned;
  }
}

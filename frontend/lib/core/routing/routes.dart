/// Single navigation contract between backend search routes and the app shell.
/// Any change here must be reviewed together with the [features/search]
/// module and the [app.dart] shell.
library;

import 'package:flutter/widgets.dart';

import '../../features/diet/screens/meal_detail_screen.dart';
import '../../features/diet/screens/profile_screen.dart';
import '../../features/habits/screens/habit_detail_screen.dart';
import '../../features/medicines/pages/medicine_detail_page.dart';

/// Shell tabs in [AppShell] order.
enum AppTab {
  dashboard,
  planner,
  health,
  medicines,
  diet,
  habits,
  finance,
}

/// How a backend search `route` resolves inside the app: which tab to show
/// and, when a detail screen exists, which page to push on top.
class SearchDestination {
  const SearchDestination({this.tab, this.detail, this.documentId});

  /// Tab to select first, or null when no tab switch is needed.
  final AppTab? tab;

  /// Builds the detail page for this result, or null when the tab itself is
  /// the destination.
  final WidgetBuilder? detail;

  /// Set for `documents/<id>`: the shell fetches the document by id and
  /// pushes its detail page without switching tabs.
  final String? documentId;
}

class AppRoutes {
  AppRoutes._();

  /// Maps every backend `SearchResult.route` shape to a real destination.
  /// Unknown routes fall back to the dashboard tab (never a dead end, never
  /// a snackbar-only TODO).
  static SearchDestination resolveSearchRoute(String route) {
    final List<String> parts = route.split('/');
    if (parts.length >= 3 && parts[0] == 'planner') {
      return const SearchDestination(tab: AppTab.planner);
    }
    if (parts.length == 2 && parts[0] == 'medicines') {
      final String id = parts[1];
      return SearchDestination(
        tab: AppTab.medicines,
        detail: (_) => MedicineDetailPage(medicineId: id),
      );
    }
    if (parts.isNotEmpty && parts[0] == 'health') {
      return const SearchDestination(tab: AppTab.health);
    }
    if (parts.length >= 2 && parts[0] == 'diet') {
      if (parts[1] == 'meal' && parts.length == 3) {
        final String id = parts[2];
        return SearchDestination(
          tab: AppTab.diet,
          detail: (_) => MealDetailScreen(mealId: id),
        );
      }
      if (parts[1] == 'profile') {
        return SearchDestination(
          tab: AppTab.diet,
          detail: (_) => const ProfileScreen(),
        );
      }
      // MEAL_ITEM (`diet/meal/item/<itemId>`) and WATER_INTAKE
      // (`diet/water/<id>`) have no dedicated detail screens: items live
      // inside their meal and water entries inside the day summary, so the
      // diet tab (history + summary) is the real destination.
      return const SearchDestination(tab: AppTab.diet);
    }
    if (parts.length == 2 && parts[0] == 'habits') {
      final String id = parts[1];
      return SearchDestination(
        tab: AppTab.habits,
        detail: (_) => HabitDetailScreen(habitId: id),
      );
    }
    if (parts.isNotEmpty && parts[0] == 'finance') {
      return const SearchDestination(tab: AppTab.finance);
    }
    if (parts.length == 2 && parts[0] == 'documents') {
      // Document detail needs the full object; the shell fetches it by id
      // before pushing. See [AppScope.openSearchResult].
      return SearchDestination(tab: null, documentId: parts[1]);
    }
    return const SearchDestination(tab: AppTab.dashboard);
  }
}

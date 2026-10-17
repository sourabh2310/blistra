/// Finance models: expenses split between friends, balances, settlements,
/// monthly overview and budgets. Amounts stay decimal strings on the wire and
/// become [Money] for arithmetic; never floating point.
library;

import 'package:flutter/material.dart';

import '../../core/money/money.dart';

/// Fixed expense categories (mirrors the backend enum).
enum ExpenseCategory {
  food('FOOD', 'Food & dining', Icons.restaurant_rounded, Color(0xFFFF8A4C)),
  groceries('GROCERIES', 'Groceries', Icons.local_grocery_store_rounded, Color(0xFF34C77B)),
  transport('TRANSPORT', 'Transport', Icons.directions_car_rounded, Color(0xFF4C8DFF)),
  fuel('FUEL', 'Fuel', Icons.local_gas_station_rounded, Color(0xFF7A6CFF)),
  shopping('SHOPPING', 'Shopping', Icons.shopping_bag_rounded, Color(0xFFFF5FA2)),
  bills('BILLS', 'Bills & utilities', Icons.receipt_long_rounded, Color(0xFF00B5C8)),
  rent('RENT', 'Rent', Icons.home_rounded, Color(0xFF8D6E63)),
  entertainment('ENTERTAINMENT', 'Entertainment', Icons.movie_rounded, Color(0xFFE040FB)),
  travel('TRAVEL', 'Travel', Icons.flight_rounded, Color(0xFF26A69A)),
  health('HEALTH', 'Health', Icons.favorite_rounded, Color(0xFFEF5350)),
  education('EDUCATION', 'Education', Icons.school_rounded, Color(0xFF5C6BC0)),
  gifts('GIFTS', 'Gifts', Icons.card_giftcard_rounded, Color(0xFFFFB300)),
  personalCare('PERSONAL_CARE', 'Personal care', Icons.spa_rounded, Color(0xFFAB47BC)),
  subscriptions('SUBSCRIPTIONS', 'Subscriptions', Icons.subscriptions_rounded, Color(0xFF29B6F6)),
  other('OTHER', 'Other', Icons.category_rounded, Color(0xFF90A4AE));

  const ExpenseCategory(this.wire, this.label, this.icon, this.color);

  final String wire;
  final String label;
  final IconData icon;
  final Color color;

  static ExpenseCategory fromWire(String? value) => ExpenseCategory.values
      .firstWhere((c) => c.wire == value, orElse: () => ExpenseCategory.other);
}

enum SplitType {
  none('NONE', 'Just me'),
  equal('EQUAL', 'Equally'),
  exact('EXACT', 'Exact amounts'),
  percent('PERCENT', 'Percentages'),
  shares('SHARES', 'Shares');

  const SplitType(this.wire, this.label);

  final String wire;
  final String label;

  static SplitType fromWire(String? value) =>
      SplitType.values.firstWhere((s) => s.wire == value, orElse: () => SplitType.none);
}

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;

DateTime? _date(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) => v is List
    ? v.whereType<Map<String, dynamic>>().map(parse).toList()
    : <T>[];

/// "yyyy-MM-dd" for API dates.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class UserSummary {
  const UserSummary({required this.id, required this.username, required this.displayName});

  final String id;
  final String username;
  final String displayName;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: _str(json['id']),
        username: _str(json['username']),
        displayName: _str(json['displayName'], _str(json['username'])),
      );

  @override
  bool operator ==(Object other) => other is UserSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CurrencyAmount {
  const CurrencyAmount(this.currency, this.amount);

  final String currency;
  final Money amount;

  String get display => amount.display(currencyCode: currency);

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) =>
      CurrencyAmount(_str(json['currency']), Money.tryParse(_str(json['amount'])));
}

class ExpenseShare {
  const ExpenseShare({required this.user, required this.amount, this.value});

  final UserSummary user;
  final Money amount;

  /// Percent or weight as entered (PERCENT / SHARES splits).
  final String? value;

  factory ExpenseShare.fromJson(Map<String, dynamic> json) => ExpenseShare(
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
        amount: Money.tryParse(_str(json['amount'])),
        value: json['value'] as String?,
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.spentOn,
    required this.splitType,
    required this.paidBy,
    required this.createdBy,
    required this.shares,
    required this.myShare,
    required this.myBalance,
    required this.editable,
    this.notes,
  });

  final String id;
  final String description;
  final ExpenseCategory category;
  final Money amount;
  final String currency;
  final DateTime spentOn;
  final String? notes;
  final SplitType splitType;
  final UserSummary paidBy;
  final UserSummary createdBy;
  final List<ExpenseShare> shares;
  final Money myShare;

  /// Positive: you lent this much. Negative: you borrowed it.
  final Money myBalance;
  final bool editable;

  bool get isShared => splitType != SplitType.none;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: _str(json['id']),
        description: _str(json['description']),
        category: ExpenseCategory.fromWire(json['category'] as String?),
        amount: Money.tryParse(_str(json['amount'])),
        currency: _str(json['currency'], 'INR'),
        spentOn: _date(json['spentOn']) ?? DateTime.now(),
        notes: json['notes'] as String?,
        splitType: SplitType.fromWire(json['splitType'] as String?),
        paidBy: UserSummary.fromJson(json['paidBy'] as Map<String, dynamic>? ?? const {}),
        createdBy: UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>? ?? const {}),
        shares: _list(json['shares'], ExpenseShare.fromJson),
        myShare: Money.tryParse(_str(json['myShare'])),
        myBalance: Money.tryParse(_str(json['myBalance'])),
        editable: json['editable'] == true,
      );
}

class ExpensePage {
  const ExpensePage({required this.items, required this.last, required this.total});

  final List<Expense> items;
  final bool last;
  final int total;

  factory ExpensePage.fromJson(Map<String, dynamic> json) => ExpensePage(
        items: _list(json['content'], Expense.fromJson),
        last: json['last'] as bool? ?? true,
        total: (json['totalElements'] as num?)?.toInt() ?? 0,
      );
}

class Settlement {
  const Settlement({
    required this.id,
    required this.payer,
    required this.payee,
    required this.amount,
    required this.currency,
    required this.settledOn,
    required this.editable,
    this.note,
  });

  final String id;
  final UserSummary payer;
  final UserSummary payee;
  final Money amount;
  final String currency;
  final DateTime settledOn;
  final String? note;
  final bool editable;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: _str(json['id']),
        payer: UserSummary.fromJson(json['payer'] as Map<String, dynamic>? ?? const {}),
        payee: UserSummary.fromJson(json['payee'] as Map<String, dynamic>? ?? const {}),
        amount: Money.tryParse(_str(json['amount'])),
        currency: _str(json['currency'], 'INR'),
        settledOn: _date(json['settledOn']) ?? DateTime.now(),
        note: json['note'] as String?,
        editable: json['editable'] == true,
      );
}

class Friend {
  const Friend({required this.user, required this.isFriend, required this.balances});

  final UserSummary user;

  /// False for a former friend you still share an open balance with.
  final bool isFriend;

  /// Positive: they owe you. Negative: you owe them.
  final List<CurrencyAmount> balances;

  bool get settled => balances.every((b) => b.amount.isZero);

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
        isFriend: json['friend'] != false,
        balances: _list(json['balances'], CurrencyAmount.fromJson),
      );
}

class FriendRequest {
  const FriendRequest({required this.id, required this.user});

  final String id;
  final UserSummary user;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: _str(json['id']),
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      );
}

class FriendsData {
  const FriendsData({
    required this.me,
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  final UserSummary? me;
  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;

  static const empty = FriendsData(me: null, friends: [], incoming: [], outgoing: []);

  List<Friend> get acceptedFriends => friends.where((f) => f.isFriend).toList();

  factory FriendsData.fromJson(Map<String, dynamic> json) => FriendsData(
        me: json['me'] is Map<String, dynamic>
            ? UserSummary.fromJson(json['me'] as Map<String, dynamic>)
            : null,
        friends: _list(json['friends'], Friend.fromJson),
        incoming: _list(json['incoming'], FriendRequest.fromJson),
        outgoing: _list(json['outgoing'], FriendRequest.fromJson),
      );
}

class FriendDetail {
  const FriendDetail({required this.friend, required this.expenses, required this.settlements});

  final Friend friend;
  final List<Expense> expenses;
  final List<Settlement> settlements;

  factory FriendDetail.fromJson(Map<String, dynamic> json) => FriendDetail(
        friend: Friend.fromJson(json['friend'] as Map<String, dynamic>? ?? const {}),
        expenses: _list(json['expenses'], Expense.fromJson),
        settlements: _list(json['settlements'], Settlement.fromJson),
      );
}

class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.currency,
    required this.limit,
    required this.spent,
  });

  final String id;

  /// Null for the overall monthly budget.
  final ExpenseCategory? category;
  final String currency;
  final Money limit;
  final Money spent;

  String get label => category?.label ?? 'Monthly budget';

  /// 0..n fraction of the limit used (may exceed 1 when over budget).
  double get usage => limit.isZero ? 0 : spent.toDouble() / limit.toDouble();

  bool get over => spent > limit;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: _str(json['id']),
        category: json['category'] == null ? null : ExpenseCategory.fromWire(json['category'] as String?),
        currency: _str(json['currency'], 'INR'),
        limit: Money.tryParse(_str(json['monthlyLimit'])),
        spent: Money.tryParse(_str(json['spentThisMonth'])),
      );
}

class CategoryAmount {
  const CategoryAmount(this.category, this.amount);

  final ExpenseCategory category;
  final Money amount;

  factory CategoryAmount.fromJson(Map<String, dynamic> json) => CategoryAmount(
        ExpenseCategory.fromWire(json['category'] as String?),
        Money.tryParse(_str(json['amount'])),
      );
}

class DayAmount {
  const DayAmount(this.date, this.amount);

  final DateTime date;
  final Money amount;

  factory DayAmount.fromJson(Map<String, dynamic> json) =>
      DayAmount(_date(json['date']) ?? DateTime.now(), Money.tryParse(_str(json['amount'])));
}

class CurrencyOverview {
  const CurrencyOverview({
    required this.currency,
    required this.spent,
    required this.paid,
    required this.previousMonthSpent,
    required this.todaySpent,
    required this.byCategory,
    required this.daily,
    required this.budgets,
  });

  final String currency;

  /// Your own share of everything this month.
  final Money spent;

  /// What you actually paid out (including friends' shares you fronted).
  final Money paid;
  final Money previousMonthSpent;
  final Money todaySpent;
  final List<CategoryAmount> byCategory;
  final List<DayAmount> daily;
  final List<Budget> budgets;

  Budget? get overallBudget {
    for (final b in budgets) {
      if (b.category == null) return b;
    }
    return null;
  }

  factory CurrencyOverview.fromJson(Map<String, dynamic> json) => CurrencyOverview(
        currency: _str(json['currency'], 'INR'),
        spent: Money.tryParse(_str(json['spent'])),
        paid: Money.tryParse(_str(json['paid'])),
        previousMonthSpent: Money.tryParse(_str(json['previousMonthSpent'])),
        todaySpent: Money.tryParse(_str(json['todaySpent'])),
        byCategory: _list(json['byCategory'], CategoryAmount.fromJson),
        daily: _list(json['daily'], DayAmount.fromJson),
        budgets: _list(json['budgets'], Budget.fromJson),
      );
}

class FinanceOverview {
  const FinanceOverview({
    required this.month,
    required this.currencies,
    required this.owedToYou,
    required this.youOwe,
    required this.friendCount,
    required this.pendingRequests,
  });

  final DateTime month;
  final List<CurrencyOverview> currencies;
  final List<CurrencyAmount> owedToYou;
  final List<CurrencyAmount> youOwe;
  final int friendCount;
  final int pendingRequests;

  factory FinanceOverview.fromJson(Map<String, dynamic> json) => FinanceOverview(
        month: _date(json['from']) ?? DateTime.now(),
        currencies: _list(json['currencies'], CurrencyOverview.fromJson),
        owedToYou: _list(json['owedToYou'], CurrencyAmount.fromJson),
        youOwe: _list(json['youOwe'], CurrencyAmount.fromJson),
        friendCount: (json['friendCount'] as num?)?.toInt() ?? 0,
        pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      );
}

/// One participant in a split being edited in the expense form.
class SplitEntry {
  SplitEntry(this.user, {this.value = ''});

  final UserSummary user;
  String value;
}

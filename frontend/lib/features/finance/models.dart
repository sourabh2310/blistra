/// Domain models for the finance feature.
///
/// All monetary amounts are parsed into [Money] (exact BigInt units) and all
/// dates are parsed as UTC [DateTime]. Models are immutable and only
/// constructible from the backend JSON contract.
library;

import '../../core/money/money.dart';

enum AccountType { cash, bank, savings, creditCard, wallet, other }

enum AccountStatus { active, archived }

enum CategoryType { income, expense }

enum CategoryStatus { active, archived }

enum TransactionType { income, expense }

AccountType accountTypeFromJson(String value) =>
    AccountType.values.byName(value.toLowerCase());

AccountStatus accountStatusFromJson(String value) =>
    AccountStatus.values.byName(value.toLowerCase());

CategoryType categoryTypeFromJson(String value) =>
    CategoryType.values.byName(value.toLowerCase());

CategoryStatus categoryStatusFromJson(String value) =>
    CategoryStatus.values.byName(value.toLowerCase());

TransactionType transactionTypeFromJson(String value) =>
    TransactionType.values.byName(value.toLowerCase());

String enumToJson(Enum value) => value.name.toUpperCase();

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.balance,
    required this.status,
    this.notes,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final Money openingBalance;
  final Money balance;
  final AccountStatus status;
  final String? notes;

  bool get isArchived => status == AccountStatus.archived;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: accountTypeFromJson(json['type'] as String),
        currency: json['currency'] as String,
        openingBalance: Money.parse(json['openingBalance'] as String),
        balance: Money.parse(json['balance'] as String),
        status: accountStatusFromJson(json['status'] as String),
        notes: json['notes'] as String?,
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
  });

  final String id;
  final String name;
  final CategoryType type;
  final CategoryStatus status;

  bool get isArchived => status == CategoryStatus.archived;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        type: categoryTypeFromJson(json['type'] as String),
        status: categoryStatusFromJson(json['status'] as String),
      );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.accountCurrency,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.createdAt,
    this.description,
    this.notes,
  });

  final String id;
  final String accountId;
  final String accountName;
  final String accountCurrency;
  final String categoryId;
  final String categoryName;
  final TransactionType type;
  final Money amount;
  final String currency;
  final DateTime occurredAt;
  final String? description;
  final String? notes;
  final DateTime createdAt;

  bool get isIncome => type == TransactionType.income;

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FinanceTransaction(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        accountName: json['accountName'] as String,
        accountCurrency: json['accountCurrency'] as String,
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        type: transactionTypeFromJson(json['type'] as String),
        amount: Money.parse(json['amount'] as String),
        currency: json['currency'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        description: json['description'] as String?,
        notes: json['notes'] as String?,
      );
}

class FinanceTransfer {
  const FinanceTransfer({
    required this.id,
    required this.sourceAccountId,
    required this.sourceAccountName,
    required this.destinationAccountId,
    required this.destinationAccountName,
    required this.amount,
    required this.currency,
    required this.transferredAt,
    this.note,
  });

  final String id;
  final String sourceAccountId;
  final String sourceAccountName;
  final String destinationAccountId;
  final String destinationAccountName;
  final Money amount;
  final String currency;
  final DateTime transferredAt;
  final String? note;

  factory FinanceTransfer.fromJson(Map<String, dynamic> json) =>
      FinanceTransfer(
        id: json['id'] as String,
        sourceAccountId: json['sourceAccountId'] as String,
        sourceAccountName: json['sourceAccountName'] as String,
        destinationAccountId: json['destinationAccountId'] as String,
        destinationAccountName: json['destinationAccountName'] as String,
        amount: Money.parse(json['amount'] as String),
        currency: json['currency'] as String,
        transferredAt: DateTime.parse(json['transferredAt'] as String),
        note: json['note'] as String?,
      );
}

class SummaryCategorySpend {
  const SummaryCategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final String categoryId;
  final String categoryName;
  final Money amount;

  factory SummaryCategorySpend.fromJson(Map<String, dynamic> json) =>
      SummaryCategorySpend(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        amount: Money.parse(json['amount'] as String),
      );
}

class SummaryCurrencySection {
  const SummaryCurrencySection({
    required this.currency,
    required this.income,
    required this.expense,
    required this.net,
    required this.transferIn,
    required this.transferOut,
    required this.spendingByCategory,
  });

  final String currency;
  final Money income;
  final Money expense;
  final Money net;
  final Money transferIn;
  final Money transferOut;
  final List<SummaryCategorySpend> spendingByCategory;

  factory SummaryCurrencySection.fromJson(Map<String, dynamic> json) =>
      SummaryCurrencySection(
        currency: json['currency'] as String,
        income: Money.parse(json['income'] as String),
        expense: Money.parse(json['expense'] as String),
        net: Money.parse(json['net'] as String),
        transferIn: Money.parse(json['transferIn'] as String),
        transferOut: Money.parse(json['transferOut'] as String),
        spendingByCategory: (json['spendingByCategory'] as List<dynamic>)
            .map((Object? item) =>
                SummaryCategorySpend.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class Summary {
  const Summary({required this.from, required this.to, required this.currencies});

  final DateTime from;
  final DateTime to;
  final List<SummaryCurrencySection> currencies;

  factory Summary.fromJson(Map<String, dynamic> json) => Summary(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        currencies: (json['currencies'] as List<dynamic>)
            .map((Object? item) =>
                SummaryCurrencySection.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  bool get isEmpty => items.isEmpty;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) =>
      PageResult(
        items: (json['content'] as List<dynamic>)
            .map((Object? item) => itemParser(item as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        size: json['size'] as int,
        totalElements: json['totalElements'] as int,
        totalPages: json['totalPages'] as int,
        last: json['last'] as bool,
      );
}
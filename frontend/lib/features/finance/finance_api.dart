/// Typed client for the finance REST API: expenses, friends, settlements,
/// monthly overview and budgets.
library;

import '../../core/api/api_client.dart';
import 'models.dart';

/// Everything needed to create or update an expense.
class ExpenseDraft {
  const ExpenseDraft({
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.spentOn,
    this.notes,
    this.paidBy,
    this.splitType = SplitType.none,
    this.participants = const [],
  });

  final String description;
  final ExpenseCategory category;
  final String amount;
  final String currency;
  final DateTime spentOn;
  final String? notes;

  /// Null means "me".
  final String? paidBy;
  final SplitType splitType;

  /// (userId, value) pairs; value is ignored for equal splits.
  final List<(String, String?)> participants;

  Map<String, dynamic> toJson() => {
        'description': description.trim(),
        'category': category.wire,
        'amount': amount,
        'currency': currency,
        'spentOn': isoDate(spentOn),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        if (paidBy != null) 'paidBy': paidBy,
        'splitType': splitType.wire,
        if (splitType != SplitType.none)
          'participants': [
            for (final (id, value) in participants)
              {'userId': id, if (value != null && value.isNotEmpty) 'value': value},
          ],
      };
}

class FinanceApi {
  FinanceApi({required this.apiClient});

  final ApiClient apiClient;

  static const String _base = '/api/v1/finance';

  Future<FinanceOverview> overview(DateTime month) async => FinanceOverview.fromJson(
        await apiClient.get('$_base/overview', query: {
          'month': '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
        }),
      );

  Future<ExpensePage> expenses({
    DateTime? from,
    DateTime? to,
    ExpenseCategory? category,
    String? friendId,
    String? query,
    int page = 0,
    int size = 50,
  }) async =>
      ExpensePage.fromJson(await apiClient.get('$_base/expenses', query: {
        if (from != null) 'from': isoDate(from),
        if (to != null) 'to': isoDate(to),
        if (category != null) 'category': category.wire,
        'friendId': ?friendId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': '$page',
        'size': '$size',
      }));

  Future<Expense> expense(String id) async =>
      Expense.fromJson(await apiClient.get('$_base/expenses/$id'));

  Future<Expense> createExpense(ExpenseDraft draft) async =>
      Expense.fromJson(await apiClient.post('$_base/expenses', body: draft.toJson()));

  Future<Expense> updateExpense(String id, ExpenseDraft draft) async =>
      Expense.fromJson(await apiClient.put('$_base/expenses/$id', body: draft.toJson()));

  Future<void> deleteExpense(String id) => apiClient.delete('$_base/expenses/$id');

  Future<FriendsData> friends() async => FriendsData.fromJson(await apiClient.get('$_base/friends'));

  /// Returns "PENDING" or "ACCEPTED" (when they had already asked you).
  Future<String> addFriend(String username) async {
    final body = await apiClient.post('$_base/friends', body: {'username': username.trim()});
    return body['status'] as String? ?? 'PENDING';
  }

  Future<void> acceptRequest(String requestId) =>
      apiClient.postNoContent('$_base/friends/requests/$requestId/accept');

  Future<void> dismissRequest(String requestId) =>
      apiClient.delete('$_base/friends/requests/$requestId');

  Future<void> removeFriend(String userId) => apiClient.delete('$_base/friends/$userId');

  Future<FriendDetail> friendDetail(String userId) async =>
      FriendDetail.fromJson(await apiClient.get('$_base/friends/$userId'));

  Future<Settlement> settleUp({
    required String friendId,
    required bool iPaid,
    required String amount,
    required String currency,
    DateTime? on,
    String? note,
  }) async =>
      Settlement.fromJson(await apiClient.post('$_base/settlements', body: {
        'friendId': friendId,
        'direction': iPaid ? 'I_PAID' : 'THEY_PAID',
        'amount': amount,
        'currency': currency,
        if (on != null) 'settledOn': isoDate(on),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  Future<void> deleteSettlement(String id) => apiClient.delete('$_base/settlements/$id');

  Future<Budget> saveBudget({
    ExpenseCategory? category,
    required String currency,
    required String monthlyLimit,
  }) async =>
      Budget.fromJson(await apiClient.put('$_base/budgets', body: {
        if (category != null) 'category': category.wire,
        'currency': currency,
        'monthlyLimit': monthlyLimit,
      }));

  Future<void> deleteBudget(String id) => apiClient.delete('$_base/budgets/$id');
}

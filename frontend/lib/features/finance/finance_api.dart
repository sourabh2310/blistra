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
    this.groupId,
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
  final String? groupId;

  Map<String, dynamic> toJson() => {
    if (groupId != null) 'groupId': groupId,
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

  Future<List<TripGroup>> groups() async =>
      (await apiClient.getList('$_base/groups'))
          .map((e) => TripGroup.fromJson(e as Map<String, dynamic>))
          .toList();
  Future<TripGroup> createGroup(String name, String currency) async =>
      TripGroup.fromJson(
        await apiClient.post(
          '$_base/groups',
          body: {'name': name.trim(), 'currency': currency},
        ),
      );
  Future<TripGroupDetail> group(String id) async =>
      TripGroupDetail.fromJson(await apiClient.get('$_base/groups/$id'));
  Future<void> archiveGroup(String id, bool archived) => apiClient
      .postNoContent('$_base/groups/$id/archive', body: {'archived': archived});
  Future<Map<String, dynamic>> exportGroup(String id) =>
      apiClient.get('$_base/groups/$id/export');
  Future<void> inviteToGroup(String id, String username) =>
      apiClient.postNoContent(
        '$_base/groups/$id/members',
        body: {'username': username.trim()},
      );
  Future<void> acceptGroup(String id) =>
      apiClient.postNoContent('$_base/groups/$id/accept');
  Future<void> leaveGroup(String id) =>
      apiClient.delete('$_base/groups/$id/membership');
  Future<void> transferGroup(String id, String userId) => apiClient
      .postNoContent('$_base/groups/$id/owner', body: {'userId': userId});
  Future<ExpensePage> groupExpenses(String id, {int page = 0}) async =>
      ExpensePage.fromJson(
        await apiClient.get(
          '$_base/groups/$id/expenses',
          query: {'page': '$page', 'size': '50'},
        ),
      );
  Future<List<Settlement>> groupPayments(String id, {int page = 0}) async =>
      (await apiClient.getList(
        '$_base/settlements',
        query: {'groupId': id, 'page': '$page', 'size': '200'},
      )).map((e) => Settlement.fromJson(e as Map<String, dynamic>)).toList();
  Future<List<Map<String, dynamic>>> history({
    String? groupId,
    String? friendId,
    int page = 0,
  }) async => (await apiClient.getList(
    '$_base/history',
    query: {'groupId': ?groupId, 'friendId': ?friendId, 'page': '$page'},
  )).map((e) => e as Map<String, dynamic>).toList();

  Future<FinanceOverview> overview(
    DateTime month,
  ) async => FinanceOverview.fromJson(
    await apiClient.get(
      '$_base/overview',
      query: {
        'month':
            '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
      },
    ),
  );

  Future<ExpensePage> expenses({
    DateTime? from,
    DateTime? to,
    ExpenseCategory? category,
    String? friendId,
    String? query,
    int page = 0,
    int size = 50,
  }) async => ExpensePage.fromJson(
    await apiClient.get(
      '$_base/expenses',
      query: {
        if (from != null) 'from': isoDate(from),
        if (to != null) 'to': isoDate(to),
        if (category != null) 'category': category.wire,
        'friendId': ?friendId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': '$page',
        'size': '$size',
      },
    ),
  );

  Future<Expense> expense(String id) async =>
      Expense.fromJson(await apiClient.get('$_base/expenses/$id'));

  Future<Expense> createExpense(ExpenseDraft draft) async => Expense.fromJson(
    await apiClient.post('$_base/expenses', body: draft.toJson()),
  );

  Future<Expense> updateExpense(String id, ExpenseDraft draft) async =>
      Expense.fromJson(
        await apiClient.put('$_base/expenses/$id', body: draft.toJson()),
      );

  Future<void> deleteExpense(String id) =>
      apiClient.delete('$_base/expenses/$id');

  Future<FriendsData> friends() async =>
      FriendsData.fromJson(await apiClient.get('$_base/friends'));

  /// Returns "PENDING" or "ACCEPTED" (when they had already asked you).
  Future<String> addFriend(String username) async {
    final body = await apiClient.post(
      '$_base/friends',
      body: {'username': username.trim()},
    );
    return body['status'] as String? ?? 'PENDING';
  }

  Future<void> acceptRequest(String requestId) =>
      apiClient.postNoContent('$_base/friends/requests/$requestId/accept');

  Future<void> dismissRequest(String requestId) =>
      apiClient.delete('$_base/friends/requests/$requestId');

  Future<void> removeFriend(String userId) =>
      apiClient.delete('$_base/friends/$userId');

  Future<FriendDetail> friendDetail(String userId) async =>
      FriendDetail.fromJson(await apiClient.get('$_base/friends/$userId'));

  Future<Settlement> settleUp({
    required String friendId,
    required bool iPaid,
    required String amount,
    required String currency,
    DateTime? on,
    String? note,
    String? groupId,
  }) async => Settlement.fromJson(
    await apiClient.post(
      '$_base/settlements',
      body: {
        'friendId': friendId,
        'groupId': ?groupId,
        'direction': iPaid ? 'I_PAID' : 'THEY_PAID',
        'amount': amount,
        'currency': currency,
        if (on != null) 'settledOn': isoDate(on),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    ),
  );

  Future<void> deleteSettlement(String id) =>
      apiClient.delete('$_base/settlements/$id');

  Future<Settlement> decideSettlement(
    String id, {
    required bool confirmed,
  }) async => Settlement.fromJson(
    await apiClient.post(
      '$_base/settlements/$id/${confirmed ? 'confirm' : 'reject'}',
      expectStatus: 200,
    ),
  );

  Future<Budget> saveBudget({
    ExpenseCategory? category,
    required String currency,
    required String monthlyLimit,
  }) async => Budget.fromJson(
    await apiClient.put(
      '$_base/budgets',
      body: {
        if (category != null) 'category': category.wire,
        'currency': currency,
        'monthlyLimit': monthlyLimit,
      },
    ),
  );

  Future<void> deleteBudget(String id) =>
      apiClient.delete('$_base/budgets/$id');
}

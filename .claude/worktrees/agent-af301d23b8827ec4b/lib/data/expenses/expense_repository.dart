import '../../models/expense.dart';
import 'expense_api.dart';

class ExpenseRepository {
  const ExpenseRepository(this._api);

  final ExpenseApi _api;

  Future<ExpenseListResult> list({
    String? propertyId,
    String? roomId,
    ExpenseCategory? category,
    String? month,
  }) {
    return _api.list(
      propertyId: propertyId,
      roomId: roomId,
      category: category,
      month: month,
    );
  }

  Future<Expense> getById(String id) => _api.getById(id);

  Future<Expense> create({
    required String propertyId,
    String? roomId,
    required ExpenseCategory category,
    required int amount,
    required String expenseDate,
    required String title,
    String? note,
    String? receiptUrl,
  }) {
    return _api.create(_payload(
      propertyId: propertyId,
      roomId: roomId,
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      title: title,
      note: note,
      receiptUrl: receiptUrl,
      includeRoomKey: false,
    ));
  }

  Future<Expense> update(
    String id, {
    required String propertyId,
    String? roomId,
    required ExpenseCategory category,
    required int amount,
    required String expenseDate,
    required String title,
    String? note,
    String? receiptUrl,
  }) {
    return _api.update(
      id,
      _payload(
        propertyId: propertyId,
        roomId: roomId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        title: title,
        note: note,
        receiptUrl: receiptUrl,
        includeRoomKey: true,
      ),
    );
  }

  Future<void> delete(String id) => _api.delete(id);

  Map<String, dynamic> _payload({
    required String propertyId,
    String? roomId,
    required ExpenseCategory category,
    required int amount,
    required String expenseDate,
    required String title,
    String? note,
    String? receiptUrl,
    bool includeRoomKey = false,
  }) {
    return {
      'propertyId': propertyId,
      if (includeRoomKey)
        'roomId': roomId == null || roomId.trim().isEmpty ? null : roomId,
      if (!includeRoomKey && roomId != null && roomId.trim().isNotEmpty)
        'roomId': roomId,
      'category': category.name,
      'amount': amount,
      'expenseDate': expenseDate,
      'title': title.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (receiptUrl != null && receiptUrl.trim().isNotEmpty)
        'receiptUrl': receiptUrl.trim(),
    };
  }
}

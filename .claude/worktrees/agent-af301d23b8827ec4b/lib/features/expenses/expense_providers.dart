import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/expenses/expense_api.dart';
import '../../data/expenses/expense_repository.dart';
import '../../models/expense.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../rooms/property_selection_provider.dart';

final expenseApiProvider = Provider<ExpenseApi>((ref) {
  return ExpenseApi(ref.watch(dioProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(expenseApiProvider));
});

class ExpenseListQuery {
  const ExpenseListQuery({
    this.propertyId,
    this.roomId,
    this.category,
    this.month,
  });

  final String? propertyId;
  final String? roomId;
  final ExpenseCategory? category;
  final String? month;

  @override
  bool operator ==(Object other) {
    return other is ExpenseListQuery &&
        other.propertyId == propertyId &&
        other.roomId == roomId &&
        other.category == category &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(propertyId, roomId, category, month);
}

final expenseListProvider =
    FutureProvider.family<ExpenseListResult, ExpenseListQuery>((ref, query) {
  final selectedPropertyId = ref.watch(selectedPropertyProvider);
  return ref.watch(expenseRepositoryProvider).list(
        propertyId: query.propertyId ?? selectedPropertyId,
        roomId: query.roomId,
        category: query.category,
        month: query.month,
      );
});

final expenseDetailProvider =
    FutureProvider.autoDispose.family<Expense, String>((ref, id) {
  return ref.watch(expenseRepositoryProvider).getById(id);
});

class ExpenseFormController extends AutoDisposeAsyncNotifier<Expense?> {
  @override
  Future<Expense?> build() async => null;

  Future<Expense> submit({
    String? expenseId,
    required String propertyId,
    String? roomId,
    required ExpenseCategory category,
    required int amount,
    required String expenseDate,
    required String title,
    String? note,
    String? receiptUrl,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      final repo = ref.read(expenseRepositoryProvider);
      if (expenseId == null) {
        return repo.create(
          propertyId: propertyId,
          roomId: roomId,
          category: category,
          amount: amount,
          expenseDate: expenseDate,
          title: title,
          note: note,
          receiptUrl: receiptUrl,
        );
      }
      return repo.update(
        expenseId,
        propertyId: propertyId,
        roomId: roomId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        title: title,
        note: note,
        receiptUrl: receiptUrl,
      );
    });
    state = result;
    if (result.hasValue) _invalidateExpenses(ref);
    return result.value ?? (throw result.error!);
  }
}

final expenseFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<ExpenseFormController, Expense?>(
  ExpenseFormController.new,
);

class ExpenseDeleteController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(expenseRepositoryProvider).delete(id);
    });
    state = result;
    if (!result.hasError) _invalidateExpenses(ref);
    if (result.hasError) throw result.error!;
  }
}

final expenseDeleteControllerProvider =
    AutoDisposeAsyncNotifierProvider<ExpenseDeleteController, void>(
  ExpenseDeleteController.new,
);

void _invalidateExpenses(Ref ref) {
  ref.invalidate(expenseListProvider);
  ref.invalidate(dashboardMetricsProvider);
}

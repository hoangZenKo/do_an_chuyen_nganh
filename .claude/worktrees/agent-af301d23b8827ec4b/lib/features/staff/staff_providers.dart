import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/staff/staff_api.dart';
import '../../data/staff/staff_repository.dart';
import '../../models/staff.dart';
import '../auth/auth_providers.dart';

final staffApiProvider = Provider<StaffApi>((ref) {
  return StaffApi(ref.watch(dioProvider));
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(staffApiProvider));
});

final staffMembersProvider = FutureProvider<List<StaffMember>>((ref) {
  return ref.watch(staffRepositoryProvider).list();
});

final staffPresetsProvider = FutureProvider<List<StaffPreset>>((ref) {
  return ref.watch(staffRepositoryProvider).presets();
});

class StaffController extends AutoDisposeAsyncNotifier<StaffInvite?> {
  @override
  Future<StaffInvite?> build() async => null;

  Future<StaffInvite> createInvite({
    required String email,
    required String fullName,
    String? phone,
    String preset = 'viewer',
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(staffRepositoryProvider).createInvite(
            email: email,
            fullName: fullName,
            phone: phone,
            preset: preset,
          );
    });
    state = result;
    if (result.hasValue) ref.invalidate(staffMembersProvider);
    return result.value ?? (throw result.error!);
  }

  Future<void> setActive(String id, bool isActive) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(staffRepositoryProvider).setActive(id, isActive);
    });
    state = const AsyncValue<StaffInvite?>.data(null);
    if (result.hasValue) ref.invalidate(staffMembersProvider);
    if (result.hasError) throw result.error!;
  }
}

final staffControllerProvider =
    AutoDisposeAsyncNotifierProvider<StaffController, StaffInvite?>(
  StaffController.new,
);

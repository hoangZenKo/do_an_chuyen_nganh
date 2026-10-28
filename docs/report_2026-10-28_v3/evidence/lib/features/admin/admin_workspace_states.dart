import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_failure.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đang tải dữ liệu quản trị',
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: light
                  ? Theme.of(context).colorScheme.surface
                  : AdminOverviewTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: light
                      ? Theme.of(context).colorScheme.outlineVariant
                      : AdminOverviewTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(minHeight: 4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.sync_outlined,
                      size: 18,
                      color: light
                          ? Theme.of(context).colorScheme.primary
                          : AdminOverviewTheme.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đang tải dữ liệu…',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: light
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : AdminOverviewTheme.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class AdminFailureState extends ConsumerWidget {
  const AdminFailureState(
      {super.key,
      required this.error,
      required this.retry,
      this.light = false});
  final Object error;
  final VoidCallback retry;
  final bool light;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = error is ApiFailure ? error as ApiFailure : null;
    final expired =
        failure?.statusCode == 401 || failure?.code == 'SESSION_CHANGED';
    final forbidden = failure?.statusCode == 403;
    final conflict = failure?.statusCode == 409;
    final mfa = failure?.code == 'ADMIN_MFA_REQUIRED' ||
        failure?.code == 'ADMIN_MFA_ENROLLMENT_REQUIRED';
    final title = expired
        ? 'Phiên đăng nhập đã hết hạn hoặc thay đổi.'
        : mfa
            ? 'Cần thiết lập bảo mật admin.'
            : forbidden
                ? 'Bạn không có quyền mở chức năng này.'
                : conflict
                    ? 'Dữ liệu đã thay đổi. Hãy tải lại trước khi thao tác.'
                    : 'Không tải được dữ liệu. Kiểm tra kết nối và thử lại.';
    final tone = light
        ? Theme.of(context).colorScheme.error
        : (expired || mfa || conflict)
            ? AdminOverviewTheme.amber
            : AdminOverviewTheme.red;
    final icon = expired
        ? Icons.lock_clock_outlined
        : mfa
            ? Icons.verified_user_outlined
            : forbidden
                ? Icons.gpp_bad_outlined
                : conflict
                    ? Icons.sync_problem_outlined
                    : Icons.error_outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: light
              ? Theme.of(context).colorScheme.surface
              : AdminOverviewTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (failure?.requestId != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: light
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : AdminOverviewTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: light
                                    ? Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                    : AdminOverviewTheme.line),
                          ),
                          child: SelectableText(
                            'Mã yêu cầu: ${failure!.requestId}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: light
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : AdminOverviewTheme.muted,
                                    ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (expired)
                  OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập lại'))
                else
                  OutlinedButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(conflict ? 'Tải dữ liệu mới' : 'Thử lại')),
                if (mfa)
                  TextButton(
                      onPressed: () =>
                          GoRouter.maybeOf(context)?.go(adminSecurityRoute),
                      child: const Text('Mở bảo mật')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

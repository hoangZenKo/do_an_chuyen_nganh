import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_workspace_scaffold.dart';
import '../auth/auth_navigation.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

class AdminPropertyFormScreen extends ConsumerStatefulWidget {
  const AdminPropertyFormScreen({super.key, this.propertyId, this.landlordId});

  final String? propertyId;
  final String? landlordId;

  @override
  ConsumerState<AdminPropertyFormScreen> createState() =>
      _AdminPropertyFormScreenState();
}

class _AdminPropertyFormScreenState
    extends ConsumerState<AdminPropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _landlordSearch = TextEditingController();
  String? _selectedLandlordId;
  _LandlordOption? _selectedLandlord;
  String? _landlordError;
  var _prefilled = false;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _selectedLandlordId = widget.landlordId;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _landlordSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (owner == null || owner != _owner) return const SizedBox.shrink();
    if (rights.isLoading) return const Scaffold(body: AdminLoadingState());
    if (rights.hasError) {
      return Scaffold(
          body: AdminFailureState(
              error: rights.error!,
              retry: () => ref.invalidate(adminCapabilitiesProvider)));
    }
    if (!rights.requireValue.has('admin.properties.manage')) {
      return const Scaffold(
          body: WorkflowEmpty('Bạn không có quyền chỉnh sửa khu trọ.'));
    }
    final propertyId = widget.propertyId;
    final routeLandlordId = widget.landlordId;
    final isEditing = propertyId != null;
    final async = ref.watch(adminPropertyFormControllerProvider);
    final detailAsync =
        isEditing ? ref.watch(adminPropertyDetailProvider(propertyId)) : null;
    final routeLandlordAsync = !isEditing && routeLandlordId != null
        ? ref.watch(adminLandlordDetailProvider(routeLandlordId))
        : null;

    detailAsync?.whenData((property) {
      if (_prefilled) return;
      _prefilled = true;
      final landlord = property.landlord;
      _selectedLandlordId = landlord?.id;
      _selectedLandlord = landlord == null
          ? null
          : _LandlordOption(
              id: landlord.id,
              fullName: landlord.fullName,
              email: landlord.email,
              phone: landlord.phone,
            );
      _name.text = property.name;
      _address.text = property.address;
    });

    routeLandlordAsync?.whenData((landlord) {
      if (_selectedLandlord != null) return;
      _selectedLandlordId = landlord.id;
      _selectedLandlord = _LandlordOption.fromSummary(landlord);
    });

    return AdminWorkspaceScaffold(
      title: isEditing ? 'Chỉnh sửa khu trọ' : 'Thêm khu trọ',
      location: adminPropertyFormRoute,
      busy: async.isLoading,
      body: detailAsync?.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AdminOverviewTheme.blue),
            ),
            error: (error, _) => Center(child: Text('$error')),
            data: (_) => _FormBody(
              formKey: _formKey,
              name: _name,
              address: _address,
              landlordSearch: _landlordSearch,
              selectedLandlord: _selectedLandlord,
              landlordError: _landlordError,
              isEditing: isEditing,
              loading: async.isLoading,
              error: async.error,
              onSearchChanged: (_) => setState(() {}),
              onSelectLandlord: _selectLandlord,
              onSubmit: () => _submit(context, propertyId),
            ),
          ) ??
          _FormBody(
            formKey: _formKey,
            name: _name,
            address: _address,
            landlordSearch: _landlordSearch,
            selectedLandlord: _selectedLandlord,
            landlordError: _landlordError,
            isEditing: isEditing,
            loading: async.isLoading,
            error: async.error,
            onSearchChanged: (_) => setState(() {}),
            onSelectLandlord: _selectLandlord,
            onSubmit: () => _submit(context, propertyId),
          ),
    );
  }

  void _selectLandlord(AdminLandlordSummary landlord) {
    setState(() {
      _selectedLandlordId = landlord.id;
      _selectedLandlord = _LandlordOption.fromSummary(landlord);
      _landlordError = null;
    });
  }

  Future<void> _submit(BuildContext context, String? propertyId) async {
    if (_owner == null ||
        ref.read(sessionIdentityProvider) != _owner ||
        ref
                .read(adminCapabilitiesProvider)
                .valueOrNull
                ?.has('admin.properties.manage') !=
            true) {
      return;
    }
    final valid = _formKey.currentState!.validate();
    if (propertyId == null && (_selectedLandlordId ?? '').isEmpty) {
      setState(() => _landlordError = 'Vui lòng chọn chủ trọ.');
      return;
    }
    if (!valid) return;

    try {
      await ref.read(adminPropertyFormControllerProvider.notifier).submit(
            propertyId: propertyId,
            landlordId: _selectedLandlordId,
            name: _name.text,
            address: _address.text,
          );
      if (context.mounted && ref.read(sessionIdentityProvider) == _owner) {
        context.pop();
      }
    } catch (_) {
      // Provider state renders the error banner.
    }
  }
}

class _FormBody extends ConsumerWidget {
  const _FormBody({
    required this.formKey,
    required this.name,
    required this.address,
    required this.landlordSearch,
    required this.selectedLandlord,
    required this.landlordError,
    required this.isEditing,
    required this.loading,
    required this.error,
    required this.onSearchChanged,
    required this.onSelectLandlord,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController landlordSearch;
  final _LandlordOption? selectedLandlord;
  final String? landlordError;
  final bool isEditing;
  final bool loading;
  final Object? error;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminLandlordSummary> onSelectLandlord;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              if (isEditing)
                _SelectedLandlordCard(
                  landlord: selectedLandlord,
                  readOnly: true,
                )
              else
                _LandlordSelector(
                  search: landlordSearch,
                  selected: selectedLandlord,
                  error: landlordError,
                  onSearchChanged: onSearchChanged,
                  onSelected: onSelectLandlord,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên khu trọ'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Địa chỉ')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          child: Text(loading
              ? 'Đang lưu…'
              : isEditing
                  ? 'Lưu thay đổi'
                  : 'Tạo khu trọ'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Semantics(
              liveRegion: true,
              child: Text('$error',
                  style: const TextStyle(color: AdminOverviewTheme.red))),
        ],
      ],
    );
  }
}

class _LandlordSelector extends ConsumerWidget {
  const _LandlordSelector({
    required this.search,
    required this.selected,
    required this.error,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final TextEditingController search;
  final _LandlordOption? selected;
  final String? error;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminLandlordSummary> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = AdminLandlordsQuery(
      search: search.text,
      status: 'active',
    );
    final landlordsAsync = ref.watch(adminLandlordsProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Chủ trọ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminOverviewTheme.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (selected != null) ...[
          _SelectedLandlordCard(landlord: selected, readOnly: false),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: search,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm chủ trọ theo tên hoặc email',
            prefixIcon: const Icon(Icons.search_rounded),
            errorText: error,
          ),
        ),
        const SizedBox(height: 10),
        landlordsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AdminOverviewTheme.blue,
                ),
              ),
            ),
          ),
          error: (error, _) => Text(
            '$error',
            style: const TextStyle(color: AdminOverviewTheme.red),
          ),
          data: (landlords) {
            if (landlords.isEmpty) {
              return const _SelectorHint('Không có chủ trọ đang hoạt động.');
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AdminOverviewTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminOverviewTheme.line),
              ),
              child: Column(
                children: landlords.take(8).map((landlord) {
                  final selectedId = selected?.id == landlord.id;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor:
                          AdminOverviewTheme.blue.withValues(alpha: 0.12),
                      child: Text(
                        landlord.fullName.trim().isNotEmpty
                            ? landlord.fullName
                                .trim()
                                .characters
                                .first
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AdminOverviewTheme.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(landlord.fullName),
                    subtitle: Text(landlord.email),
                    trailing: selectedId
                        ? const Icon(Icons.check_circle_rounded,
                            color: AdminOverviewTheme.blue)
                        : null,
                    onTap: () => onSelected(landlord),
                  );
                }).toList(growable: false),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SelectedLandlordCard extends StatelessWidget {
  const _SelectedLandlordCard({required this.landlord, required this.readOnly});

  final _LandlordOption? landlord;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final value = landlord;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: value == null
          ? Text(
              readOnly
                  ? 'Chưa có chủ trọ'
                  : 'Chọn chủ trọ đang hoạt động bên dưới',
              style: const TextStyle(color: AdminOverviewTheme.muted),
            )
          : Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AdminOverviewTheme.blue.withValues(alpha: 0.12),
                  child: Text(
                    value.fullName.trim().isNotEmpty
                        ? value.fullName.trim().characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AdminOverviewTheme.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AdminOverviewTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          value.email,
                          if ((value.phone ?? '').isNotEmpty) value.phone!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminOverviewTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (readOnly)
                  const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AdminOverviewTheme.muted),
              ],
            ),
    );
  }
}

class _SelectorHint extends StatelessWidget {
  const _SelectorHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AdminOverviewTheme.muted),
      ),
    );
  }
}

class _LandlordOption {
  const _LandlordOption({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory _LandlordOption.fromSummary(AdminLandlordSummary landlord) {
    return _LandlordOption(
      id: landlord.id,
      fullName: landlord.fullName,
      email: landlord.email,
      phone: landlord.phone,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String? phone;
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Vui lòng nhập thông tin.'
      : null;
}

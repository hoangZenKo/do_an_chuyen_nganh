import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_models.dart';
import '../tenants/widgets/form_widgets.dart';
import 'admin_providers.dart';

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

  @override
  void initState() {
    super.initState();
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

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit property' : 'Add property')),
      body: detailAsync?.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
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
    final valid = _formKey.currentState!.validate();
    if (propertyId == null && (_selectedLandlordId ?? '').isEmpty) {
      setState(() => _landlordError = 'Required');
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
      if (context.mounted) context.pop();
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
              AppTextField(
                controller: name,
                label: 'Name',
                validator: _required,
              ),
              const SizedBox(height: 12),
              AppTextField(controller: address, label: 'Address'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SubmitButton(
          label: isEditing ? 'Save changes' : 'Create property',
          loading: loading,
          onPressed: onSubmit,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          FormErrorBanner(message: '$error'),
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
            'Landlord',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
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
            hintText: 'Search active landlords by name or email',
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
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          error: (error, _) => Text(
            '$error',
            style: const TextStyle(color: Color(0xFFDC2626)),
          ),
          data: (landlords) {
            if (landlords.isEmpty) {
              return const _SelectorHint('No active landlords found.');
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: landlords.take(8).map((landlord) {
                  final selectedId = selected?.id == landlord.id;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        landlord.fullName.trim().isNotEmpty
                            ? landlord.fullName
                                .trim()
                                .characters
                                .first
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(landlord.fullName),
                    subtitle: Text(landlord.email),
                    trailing: selectedId
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary)
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: value == null
          ? Text(
              readOnly ? 'No landlord' : 'Select an active landlord below',
              style: const TextStyle(color: Color(0xFF6B7280)),
            )
          : Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    value.fullName.trim().isNotEmpty
                        ? value.fullName.trim().characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppTheme.primary,
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
                          color: Color(0xFF111827),
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
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (readOnly)
                  const Icon(Icons.lock_outline_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF6B7280)),
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
  return value == null || value.trim().isEmpty ? 'Required' : null;
}

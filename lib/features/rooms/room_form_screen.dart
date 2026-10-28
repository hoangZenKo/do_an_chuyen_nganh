import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../models/room.dart';
import 'room_providers.dart';
import 'widgets/room_image.dart';

/// Shared create/edit form for a room. When [roomId] is null the form creates a
/// room in the currently selected property; otherwise it edits that room.
class RoomFormScreen extends ConsumerWidget {
  const RoomFormScreen({super.key, this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (roomId == null) {
      final propertyId = ref.watch(selectedPropertyProvider);
      if (propertyId == null) {
        return const _FormScaffold(
          title: 'Thêm phòng',
          child: Center(
            child: Text('Vui lòng chọn khu trọ trước.',
                style: TextStyle(color: Color(0xFF8891A8))),
          ),
        );
      }
      return _FormScaffold(
        title: 'Thêm phòng',
        child: _RoomForm(propertyId: propertyId),
      );
    }

    final roomAsync = ref.watch(roomDetailProvider(roomId!));
    return _FormScaffold(
      title: 'Sửa phòng',
      child: roomAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(
          child:
              Text('$error', style: const TextStyle(color: Color(0xFF8891A8))),
        ),
        data: (room) => _RoomForm(propertyId: room.propertyId, existing: room),
      ),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _RoomForm extends ConsumerStatefulWidget {
  const _RoomForm({required this.propertyId, this.existing});

  final String propertyId;
  final Room? existing;

  @override
  ConsumerState<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends ConsumerState<_RoomForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _floor;
  late final TextEditingController _area;
  late final TextEditingController _price;
  late final TextEditingController _capacity;
  late final TextEditingController _imageUrl;
  late final TextEditingController _note;
  late RoomStatus _status;
  late Set<String> _amenities;
  bool _submitting = false;
  String? _error;

  /// Preset amenity options; users can toggle these on/off.
  static const _amenityOptions = [
    'Nóng lạnh',
    'Wifi',
    'Máy lạnh',
    'Ban công',
    'Gác lửng',
    'Tủ lạnh',
    'Máy giặt',
    'Bếp',
  ];

  @override
  void initState() {
    super.initState();
    final room = widget.existing;
    _name = TextEditingController(text: room?.name ?? '');
    _floor = TextEditingController(text: room?.floor?.toString() ?? '');
    _area = TextEditingController(text: room?.areaSqm?.toString() ?? '');
    _price = TextEditingController(text: room?.basePrice.toString() ?? '');
    _capacity = TextEditingController(text: room?.capacity?.toString() ?? '');
    _imageUrl = TextEditingController(text: room?.imageUrl ?? '');
    _note = TextEditingController(text: room?.note ?? '');
    _status = room?.status ?? RoomStatus.vacant;
    _amenities = {...?room?.amenities};
  }

  @override
  void dispose() {
    _name.dispose();
    _floor.dispose();
    _area.dispose();
    _price.dispose();
    _capacity.dispose();
    _imageUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final draft = Room(
      id: widget.existing?.id ?? '',
      propertyId: widget.propertyId,
      name: _name.text.trim(),
      status: _status,
      floor: int.tryParse(_floor.text.trim()),
      areaSqm: double.tryParse(_area.text.trim().replaceAll(',', '.')),
      basePrice: int.tryParse(_price.text.trim()) ?? 0,
      capacity: int.tryParse(_capacity.text.trim()),
      amenities: _amenities.toList(),
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    try {
      await ref.read(roomFormControllerProvider.notifier).submit(
            propertyId: widget.propertyId,
            existing: widget.existing,
            draft: draft,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is ApiFailure
            ? error.message
            : 'Không thể lưu phòng. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          _Field(
            controller: _name,
            label: 'Tên phòng',
            hint: 'P.201',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nhập tên phòng' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  controller: _floor,
                  label: 'Tầng',
                  hint: '2',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  controller: _area,
                  label: 'Diện tích (m²)',
                  hint: '25',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  controller: _price,
                  label: 'Giá thuê (đ)',
                  hint: '3500000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final value = int.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) return 'Nhập giá hợp lệ';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  controller: _capacity,
                  label: 'Sức chứa (người)',
                  hint: '2',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Trạng thái'),
          const SizedBox(height: 8),
          _StatusChips(
            value: _status,
            onChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 16),
          const _Label('Ảnh phòng'),
          const SizedBox(height: 8),
          _ImagePicker(
            selected: _imageUrl.text.trim(),
            onSelected: (path) => setState(() => _imageUrl.text = path),
          ),
          const SizedBox(height: 16),
          const _Label('Tiện nghi'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenityOptions.map((a) {
              final selected = _amenities.contains(a);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _amenities.remove(a);
                  } else {
                    _amenities.add(a);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.teal.withValues(alpha: 0.12)
                        : const Color(0xFF22263A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.teal : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? AppTheme.teal : const Color(0xFF8891A8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _note,
            label: 'Ghi chú',
            hint: 'Tuỳ chọn',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      widget.existing == null ? 'Tạo phòng' : 'Lưu thay đổi',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RoomImageCatalog.presetImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = RoomImageCatalog.presetImages[index];
          final isSelected = selected == image;
          return GestureDetector(
            onTap: () => onSelected(image),
            child: Container(
              width: 128,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primary : const Color(0xFF2E3348),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RoomImageView(
                      source: image,
                      placeholder: const _ImagePickerPlaceholder(),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImagePickerPlaceholder extends StatelessWidget {
  const _ImagePickerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF22263A),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

// ── Form widgets ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF0F2FF),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFFF0F2FF),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF8891A8),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF22263A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E3348), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.teal, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});

  final RoomStatus value;
  final ValueChanged<RoomStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RoomStatus.values.map((status) {
        final isSelected = status == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: status != RoomStatus.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? status.color.withValues(alpha: 0.1)
                      : const Color(0xFF22263A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? status.color : const Color(0xFF2E3348),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? status.color : const Color(0xFF8891A8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

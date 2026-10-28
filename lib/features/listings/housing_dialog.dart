import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import 'housing_providers.dart';

enum HousingForm { booking, lease, feedback, viewingAction }

class HousingFormValue {
  const HousingFormValue(
      this.date, this.note, this.rent, this.deposit, this.stage, this.rating,
      [this.slotId]);
  final String? slotId;
  final DateTime date;
  final String note, stage;
  final int rent, deposit, rating;
}

class HousingDialog extends ConsumerStatefulWidget {
  const HousingDialog(
      {super.key,
      required this.title,
      required this.form,
      required this.accountId,
      required this.onSubmit,
      this.rent = 0,
      this.deposit = 0,
      this.listingId,
      this.requireNote = false,
      this.description});
  final String title, accountId;
  final String? description;
  final String? listingId;
  final bool requireNote;
  final HousingForm form;
  final int rent, deposit;
  final Future<void> Function(HousingFormValue) onSubmit;
  @override
  ConsumerState<HousingDialog> createState() => _HousingDialogState();
}

class _HousingDialogState extends ConsumerState<HousingDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  late final _rent = TextEditingController(text: '${widget.rent}');
  late final _deposit = TextEditingController(text: '${widget.deposit}');
  late DateTime _date = widget.form == HousingForm.booking
      ? DateTime.now().add(const Duration(days: 1))
      : DateTime.now();
  String _stage = 'discovery';
  int _rating = 4;
  bool _busy = false;
  String? _error;
  String? _slotId;

  @override
  void dispose() {
    _note.dispose();
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)));
    if (date == null || !mounted) return;
    if (widget.form == HousingForm.booking) {
      final time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(_date));
      if (time == null || !mounted) return;
      setState(() => _date =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    } else {
      setState(() => _date = date);
    }
  }

  Future<void> _submit() async {
    if (_busy ||
        ref.read(sessionIdentityProvider) != widget.accountId ||
        !_form.currentState!.validate()) {
      return;
    }
    if (widget.listingId != null) {
      final slots =
          ref.read(viewingSlotsProvider(widget.listingId!)).asData?.value;
      if (slots == null || (slots.required && _slotId == null)) {
        setState(() => _error = 'Chọn một khung giờ còn trống của chủ trọ.');
        return;
      }
    }
    if (widget.form == HousingForm.booking &&
        _date.difference(DateTime.now()) < const Duration(minutes: 15)) {
      setState(() => _error = 'Chọn giờ hẹn cách hiện tại ít nhất 15 phút.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(HousingFormValue(
          _date,
          _note.text.trim(),
          int.tryParse(_rent.text) ?? 0,
          int.tryParse(_deposit.text) ?? 0,
          _stage,
          _rating,
          _slotId));
      if (mounted && ref.read(sessionIdentityProvider) == widget.accountId) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _money(TextEditingController controller, String label, int minimum) =>
      TextFormField(
          controller: controller,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, suffixText: 'đ'),
          validator: (value) {
            final amount = int.tryParse(value ?? '');
            return amount == null || amount < minimum || amount > 2147483647
                ? 'Nhập số tiền hợp lệ.'
                : null;
          });

  @override
  Widget build(BuildContext context) {
    final availability = widget.listingId == null
        ? null
        : ref.watch(viewingSlotsProvider(widget.listingId!));
    final sameAccount = ref.watch(sessionIdentityProvider) == widget.accountId;
    if (!sameAccount) {
      return AlertDialog(
          title: const Text('Phiên đăng nhập đã thay đổi'),
          content: const Text(
              'Đóng cửa sổ và thực hiện lại bằng tài khoản hiện tại.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'))
          ]);
    }
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.description != null) ...[
                              Text(widget.description!),
                              const SizedBox(height: 16)
                            ],
                            if (availability != null)
                              availability.when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (error, _) => ListingMessage(
                                      title: 'Chưa tải được khung giờ',
                                      message: listingError(error),
                                      onRetry: () => ref.invalidate(
                                          viewingSlotsProvider(
                                              widget.listingId!))),
                                  data: (value) {
                                    if (!value.required) {
                                      return const Text(
                                          'Chủ trọ chưa mở khung cố định. Bạn có thể đề xuất giờ hẹn; lịch mặc định 30 phút.');
                                    }
                                    final slots = value.slots
                                        .where((slot) => slot.available)
                                        .toList();
                                    if (slots.isEmpty) {
                                      return const Text(
                                          'Chưa có khung giờ trống. Chủ trọ cần mở thêm lịch trước khi đặt.');
                                    }
                                    return DropdownButtonFormField<String>(
                                        itemHeight: null,
                                        isDense: false,
                                        value: slots.any(
                                                (slot) => slot.id == _slotId)
                                            ? _slotId
                                            : null,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Khung giờ còn trống (giờ thiết bị)'),
                                        items: [
                                          for (final slot in slots)
                                            DropdownMenuItem(
                                                value: slot.id,
                                                child: Text(
                                                    '${formatDate(slot.startsAt)} · ${TimeOfDay.fromDateTime(slot.startsAt).format(context)} – ${TimeOfDay.fromDateTime(slot.endsAt).format(context)}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis))
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (id) => setState(() {
                                                  _slotId = id;
                                                  _date = slots
                                                      .firstWhere((slot) =>
                                                          slot.id == id)
                                                      .startsAt;
                                                }),
                                        validator: (value) => value == null
                                            ? 'Chọn khung giờ.'
                                            : null);
                                  }),
                            if ((widget.form == HousingForm.booking &&
                                    (availability == null ||
                                        availability.asData?.value.required ==
                                            false)) ||
                                widget.form == HousingForm.lease)
                              OutlinedButton.icon(
                                  onPressed: _busy ? null : _pickDate,
                                  icon: const Icon(Icons.event_outlined),
                                  label: Text(
                                      '${widget.form == HousingForm.lease ? 'Bắt đầu' : 'Giờ hẹn'}: ${formatDate(_date)}${widget.form == HousingForm.booking ? ' · ${TimeOfDay.fromDateTime(_date).format(context)}' : ''}')),
                            if (widget.form == HousingForm.lease) ...[
                              _money(_rent, 'Tiền thuê / tháng', 1),
                              const SizedBox(height: 12),
                              _money(_deposit, 'Tiền cọc thỏa thuận', 0),
                              const SizedBox(height: 12),
                              const Text(
                                  'Tạo hợp đồng có hiệu lực và liên kết tài khoản người thuê. Chưa ghi nhận đã thu cọc; chủ trọ ghi giao dịch khi thực nhận tiền.'),
                            ],
                            if (widget.form == HousingForm.feedback) ...[
                              DropdownButtonFormField<String>(
                                  value: _stage,
                                  decoration: const InputDecoration(
                                      labelText: 'Luồng đã thử'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'discovery',
                                        child: Text('Tìm phòng')),
                                    DropdownMenuItem(
                                        value: 'viewing',
                                        child: Text('Xem phòng')),
                                    DropdownMenuItem(
                                        value: 'rental',
                                        child: Text('Đang thuê'))
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (value) =>
                                          setState(() => _stage = value!)),
                              DropdownButtonFormField<int>(
                                  value: _rating,
                                  decoration: const InputDecoration(
                                      labelText: 'Mức hài lòng'),
                                  items: [
                                    for (var rating = 1; rating <= 5; rating++)
                                      DropdownMenuItem(
                                          value: rating,
                                          child: Text('$rating / 5'))
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (value) =>
                                          setState(() => _rating = value!)),
                            ],
                            if (widget.form != HousingForm.lease) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _note,
                                  enabled: !_busy,
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: widget.form == HousingForm.feedback
                                      ? 2000
                                      : 1000,
                                  decoration: InputDecoration(
                                      labelText:
                                          widget.form == HousingForm.feedback
                                              ? 'Điểm vướng và đề xuất'
                                              : widget.requireNote
                                                  ? 'Lý do hủy lịch'
                                                  : 'Ghi chú (không bắt buộc)'),
                                  validator: (value) => widget.requireNote &&
                                          (value?.trim().isEmpty ?? true)
                                      ? 'Nhập lý do để người còn lại biết.'
                                      : widget.form == HousingForm.feedback &&
                                              (value?.trim().length ?? 0) < 10
                                          ? 'Nhập ít nhất 10 ký tự.'
                                          : null),
                            ],
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                          ])))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Đóng')),
            FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Đang lưu…' : 'Xác nhận'))
          ],
        ));
  }
}

import re

LABELS = {
    'amount': 'Số tiền', 'monthlyRent': 'Tiền thuê tháng', 'deposit': 'Tiền cọc',
    'basePrice': 'Giá phòng', 'price': 'Giá', 'unitPrice': 'Đơn giá',
    'electricity': 'Chỉ số điện', 'water': 'Chỉ số nước',
    'previousReading': 'Chỉ số trước', 'currentReading': 'Chỉ số hiện tại',
    'finalElectricity': 'Chỉ số điện cuối', 'finalWater': 'Chỉ số nước cuối',
    'electricityKwh': 'Điện tiêu thụ dự kiến', 'waterM3': 'Nước tiêu thụ dự kiến',
    'electricityUnitPrice': 'Đơn giá điện', 'waterUnitPrice': 'Đơn giá nước',
    'actualCost': 'Chi phí thực tế', 'estimatedCost': 'Chi phí dự kiến',
    'maxBudget': 'Ngân sách tối đa', 'otherAmount': 'Khoản tiền khác',
    'capacity': 'Sức chứa', 'quantity': 'Số lượng', 'areaSqm': 'Diện tích',
    'months': 'Số tháng', 'invoiceDay': 'Ngày lập hóa đơn trong tháng',
    'dueDay': 'Ngày đến hạn trong tháng', 'radiusKm': 'Bán kính tìm kiếm tính theo km',
    'roomRating': 'Điểm phòng ở', 'costRating': 'Điểm chi phí',
    'landlordRating': 'Điểm chủ trọ', 'areaRating': 'Điểm khu vực',
    'rating': 'Điểm đánh giá', 'maxOpen': 'Số hồ sơ mở tối đa',
    'maxProperties': 'Hạn mức khu', 'maxRooms': 'Hạn mức phòng',
    'rollout': 'Tỷ lệ áp dụng tính theo phần trăm',
    'allocations': 'Danh sách phân bổ', 'imageUrls': 'Danh sách ảnh',
    'proofImageUrls': 'Danh sách ảnh chứng từ', 'readings': 'Danh sách chỉ số',
    'tenantIds': 'Danh sách người thuê nhận thông báo', 'checklist': 'Danh sách mục kiểm tra',
}

def business_checks(entry):
    alternatives = {}
    for definition in entry.get('dtoFacts', []):
        for field in definition.get('fields', []):
            name = field['name']
            if name not in LABELS:
                continue
            checks = []
            for constraint in field.get('constraints', []):
                match = re.fullmatch(r'@(Min|Max|ArrayMaxSize|ArrayMinSize)\((\d+(?:\.\d+)?)\)', constraint)
                if match:
                    checks.append((match.group(1), match.group(2)))
            if checks:
                alternatives.setdefault(name, set()).add(tuple(checks))
    result = []
    for name, variants in alternatives.items():
        if len(variants) != 1:
            continue
        values = dict(next(iter(variants)))
        label = LABELS[name]
        if 'ArrayMinSize' in values or 'ArrayMaxSize' in values:
            limits = []
            if 'ArrayMinSize' in values:
                limits.append('ít nhất ' + values['ArrayMinSize'])
            if 'ArrayMaxSize' in values:
                limits.append('tối đa ' + values['ArrayMaxSize'])
            result.append(label + ': ' + ', '.join(limits) + ' phần tử.')
        elif 'Min' in values or 'Max' in values:
            if 'Min' in values and 'Max' in values:
                result.append(label + ': từ ' + values['Min'] + ' đến ' + values['Max'] + '.')
            elif 'Min' in values:
                result.append(label + ': không nhỏ hơn ' + values['Min'] + '.')
            else:
                result.append(label + ': không vượt ' + values['Max'] + '.')
    return ('\nKiểm tra bổ sung khi trường tương ứng được cung cấp trong trường hợp áp dụng:\n' + '\n'.join(result)) if result else ''

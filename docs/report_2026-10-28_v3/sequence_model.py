import json
from pathlib import Path

MODELS = {}

def message(sender, receiver, text, kind='call'):
    return dict(type='message', sender=sender, receiver=receiver, text=text, kind=kind)

def call(sender, receiver, text):
    return message(sender, receiver, text)

def reply(sender, receiver, text):
    return message(sender, receiver, text, 'return')

def query(text, result):
    return [call('service', 'data', text), reply('data', 'service', result)]

def fragment(kind, guard, children, alternate=None):
    return dict(type='fragment', kind=kind, guard=guard, children=children, alternate=alternate)

def fail(guard, text):
    return fragment('break', guard, [reply('service', 'ui', text)])

def add(key, title, actor, service, pre, post, events, methods, second=None, data='PostgreSQL'):
    participants=[dict(id='actor', name=actor, kind='actor'),dict(id='ui', name='Giao diện Flutter', kind='boundary'),dict(id='service', name=service, kind='control'),dict(id='data', name=data, kind='entity')]
    if second:
        participants.append(dict(id='second', name=second, kind='actor'))
    MODELS[key]=dict(id=key,title=title,participants=participants,pre=pre,post=post,events=events,methods=methods)

add('SD-01','Đăng nhập và gia hạn phiên','Khách vãng lai','AuthService',
    'Tài khoản đã đăng ký; màn hình chưa có phiên hoặc đang khôi phục phiên.',
    'Chỉ lưu token do backend trả về; refresh từ chối xác thực thì yêu cầu đăng nhập lại, lỗi mạng cho phép thử lại.',[
    call('actor','ui','Nhập email và mật khẩu'),call('ui','service','login(email, password)'),
    *query('Đọc User theo email','User hoặc không tồn tại'),
    fail('Không có user, bị khóa hoặc sai mật khẩu','401; không tạo phiên'),
    fragment('opt','Admin đã bật MFA',[
        call('service','service','Xác minh mã MFA / mã khôi phục'),
        fail('Thiếu hoặc sai mã MFA','MFA_REQUIRED / lỗi xác thực')]),
    *query('TX: khóa User; kiểm tra version; tạo session và refresh token','Commit phiên và hạn token'),
    reply('service','ui','Access token, refresh token, user'),
    call('ui','ui','Lưu phiên an toàn; mở đúng vai trò'),
    fragment('opt','Cần gia hạn access token',[
        call('ui','service','refresh(rawToken)'),
        *query('TX: khóa User; đọc token và session','Trạng thái, hạn và userVersion'),
        fail('Hết hạn, thu hồi hoặc version sai','401; yêu cầu đăng nhập lại'),
        *query('Thu hồi token cũ; ghi token thay thế','Commit luân chuyển một lần'),
        reply('service','ui','Cặp token mới và thông tin phiên')])],
    [('auth/auth.service.ts','login'),('auth/auth.service.ts','refresh'),('auth/auth.service.ts','issueSession')])

add('SD-02','Đặt lịch xem và tạo hợp đồng từ lịch','Người thuê','HousingService',
    'Người thuê có phiên tìm phòng; tin đang nhận khách; chủ trọ dùng phiên riêng.',
    'LEASED chỉ sau khi tạo lease thành công; tin được ẩn và lịch khác được xử lý trong cùng transaction.',[
    call('actor','ui','Chọn tin, thời gian và slot'),call('ui','service','book(listingId, scheduledAt, slotId)'),
    *query('TX: kiểm tra tin; reserveTime()','Tin khả dụng và slot hợp lệ'),
    fail('Tin ngừng nhận hoặc trùng giờ / hết slot','Lỗi; không tạo lịch xem'),
    *query('Tạo REQUESTED và thông báo nội bộ','Commit lịch xem'),reply('service','ui','Lịch REQUESTED và version'),
    call('second','ui','Xác nhận rồi ghi đã xem sau giờ hẹn'),call('ui','service','update(CONFIRMED / COMPLETED)'),
    *query('Khóa lịch; kiểm tra giờ, quyền, version; cập nhật','Lịch COMPLETED'),reply('service','ui','Trạng thái mới và version'),
    call('second','ui','Chọn tạo hợp đồng'),call('ui','service','createLease(viewingId, version, terms)'),
    *query('TX: khóa lịch; kiểm tra COMPLETED, tin và tenant','Trạng thái hiện hành'),
    fail('Phòng đổi trạng thái hoặc tenant ngoài scope','409; không tạo lease'),
    *query('Tạo lease; LEASED; ẩn tin; hủy lịch còn lại; audit','Commit lease và tenant'),reply('service','ui','leaseId và tenantId')],
    [('housing/housing.service.ts','book'),('housing/housing.service.ts','update'),('housing/housing.service.ts','createLease')],second='Chủ trọ')

add('SD-03','Tạo hợp đồng và ghi nhận cọc','Chủ trọ','LeasesService',
    'Có quyền tạo lease; phòng, hồ sơ người thuê và điều khoản đã được chọn.',
    'Lease ACTIVE và Room OCCUPIED đồng bộ; chỉ ghi COLLECTED nếu đầu vào cọc lớn hơn 0.',[
    call('actor','ui','Nhập phòng, tenant và điều khoản'),call('ui','service','create(leaseInput)'),
    *query('TX: khóa Room; đọc property và tenant','Phạm vi và trạng thái hiện hành'),
    fail('Ngoài scope, bị lưu trữ, inactive hoặc turnover','Từ chối; không ghi hợp đồng'),
    *query('Tìm lease ACTIVE của phòng','Có hoặc không có lease'),
    fragment('alt','Đã có lease ACTIVE',[
        reply('service','ui','ROOM_ALREADY_LEASED; rollback')],alternate=('Không có lease ACTIVE',[
        *query('Tạo Lease ACTIVE','Lease mới'),
        fragment('opt','deposit > 0',query('Ghi DepositTransaction COLLECTED','Khoản cọc được ghi')),
        *query('Cập nhật Room OCCUPIED, tenantName','Commit transaction'),
        reply('service','ui','Lease cùng thông tin phòng / tenant'),reply('ui','actor','Hiển thị hợp đồng mới')]))],
    [('leases/leases.service.ts','create'),('leases/leases.service.ts','createWithinTransaction')])

add('SD-04','Đề xuất và duyệt biểu phí','Chủ trọ','BillingTariffsService',
    'Chủ trọ đúng phạm vi khu; thao tác duyệt cần billing.tariff_approve.',
    'Giữ lịch sử giá theo hiệu lực; không áp giá đề xuất chưa được duyệt cho hóa đơn đã phát hành.',[
    call('actor','ui','Nhập biểu phí và tháng hiệu lực'),call('ui','service','propose(input, requestKey)'),
    *query('TX: kiểm tra scope, kỳ; lưu PROPOSED','Đề xuất đã lưu'),reply('service','ui','Proposal và trạng thái'),
    call('ui','service','impact(proposalId)'),*query('Đọc giá nền, phòng, invoice và kỳ khóa','Tác động và blockingReasons'),reply('service','ui','Impact và canApprove'),
    call('actor','ui','Chọn duyệt hoặc từ chối; nhập lý do'),call('ui','service','review(decision, reason, requestKey)'),
    *query('TX: khóa Property; đọc lại proposal','Trạng thái PROPOSED hiện hành'),
    fail('Đã review hoặc requestKey khác payload','409; không ghi quyết định mới'),
    fragment('alt','decision = APPROVED',[
        *query('Kiểm tra backdate, invoice, kỳ khóa, thứ tự hiệu lực','Đủ hoặc thiếu điều kiện'),
        fail('Kỳ bị chặn hoặc thứ tự không hợp lệ','Không áp giá; rollback')],alternate=('decision = REJECTED',[call('service','service','Giữ proposal; ghi lý do từ chối')])),
    *query('Ghi decision, event, audit và command','Commit kết quả review'),reply('service','ui','Biểu phí cùng trạng thái mới')],
    [('billing/billing-tariffs.service.ts','propose'),('billing/billing-tariffs.service.ts','impact'),('billing/billing-tariffs.service.ts','review')])

add('SD-05','Xem trước và phát hành hóa đơn','Chủ trọ','Billing / Tariffs',
    'Có lease trong scope, kỳ lập hóa đơn và chỉ số điện nước.',
    'Preview không giữ khóa tới lần ghi; bulk trả kết quả tạo, bỏ qua và lỗi, không giả định mọi phòng đều thành công.',[
    call('actor','ui','Chọn kỳ, hợp đồng và chỉ số'),call('ui','service','preview() / bulkInvoicePreflight()'),
    *query('Đọc lease, meter, biểu phí hiệu lực','Dữ liệu tính giá theo kỳ'),call('service','service','Tính dòng tiền, nguồn giá và lỗi thiếu'),
    reply('service','ui','Preview / kết quả từng phòng'),
    fragment('opt','Chủ trọ xác nhận phát hành',[
        call('actor','ui','Xác nhận nội dung đã xem'),call('ui','service','createInvoice() / createBulkInvoices()'),
        fragment('loop','Mỗi hợp đồng được chọn',[
            *query('TX: khóa lease / phòng; kiểm tra lại kỳ và trùng','Dữ liệu tại thời điểm ghi'),
            fragment('alt','Đủ điều kiện ghi',query('Ghi Invoice và line item snapshot','Commit hóa đơn'),alternate=('Trùng hoặc không hợp lệ',[call('service','service','Giữ lỗi / bỏ qua theo từng mục')]))]),
        reply('service','ui','Hóa đơn hoặc thống kê bulk'),reply('ui','actor','Hiển thị kết quả, không báo thành công toàn bộ')])],
    [('billing/billing-tariffs.service.ts','preview'),('billing/billing.service.ts','createInvoice'),('billing/billing.service.ts','bulkInvoicePreflight'),('billing/billing.service.ts','createBulkInvoices')])

add('SD-06','Ghi khoản thu và phân bổ nhiều hóa đơn','Chủ trọ','BillingLedgerService',
    'Có tenant thuộc chủ trọ; khoản tiền thực nhận và tham chiếu đã được xác nhận.',
    'Receipt khả dụng chưa phân bổ không giảm công nợ; Payment và Allocation chỉ được ghi trong transaction thành công.',[
    call('actor','ui','Nhập số tiền, tham chiếu, hóa đơn'),call('ui','service','createReceipt(input, requestKey)'),
    *query('TX: khóa command key; đọc hash cũ','Command cũ hoặc chưa tồn tại'),
    fragment('break','Đã có requestKey',[
        reply('service','ui','Cùng hash: kết quả cũ; khác hash: 409')]),
    *query('Kiểm tra tenant; tạo receipt khả dụng','Receipt mới trong transaction'),
    fragment('loop','Mỗi allocation; khóa invoice theo ID',[
        *query('Khóa invoice; kiểm tra tenant và dư nợ','Số dư hiện hành'),
        fail('Trùng invoice, sai tenant hoặc vượt dư','Lỗi; rollback toàn bộ lệnh'),
        *query('Tạo Payment, Allocation; cập nhật invoice','Phân bổ trong transaction')]),
    *query('Giảm available; event, audit, command','Commit receipt và số dư'),reply('service','ui','Receipt, allocations, availableAmount'),
    fragment('opt','Phân bổ thêm từ receipt đã tồn tại',[
        call('ui','service','allocate(receiptId, lines, requestKey)'),
        *query('Khóa receipt; áp dụng kiểm tra và phân bổ như trên','Commit hoặc rollback lệnh mới'),reply('service','ui','Receipt và công nợ cập nhật')])],
    [('billing/billing-ledger.service.ts','createReceipt'),('billing/billing-ledger.service.ts','allocate'),('billing/billing-ledger.service.ts','allocateLines'),('billing/billing-commands.service.ts','execute')])

add('SD-07','Giải phóng phân bổ và ghi nhận hoàn tiền','Chủ trọ','BillingLedgerService',
    'Có receipt / allocation thuộc scope; chủ trọ cung cấp lý do và requestKey riêng từng lệnh.',
    'Giữ payment gốc; hoàn tiền chỉ là ghi sổ, không chuyển khoản ngân hàng.',[
    call('actor','ui','Chọn allocation, nhập lý do'),call('ui','service','release(receiptId, allocationId, key)'),
    *query('TX: idempotency; khóa receipt và invoice','Allocation và số dư hiện tại'),
    fail('Không tồn tại, đã release hoặc sổ lệch','Từ chối; không đảo trùng'),
    *query('Ghi REVERSAL âm; release allocation; cập nhật số dư','Commit event, audit và command'),reply('service','ui','Receipt khả dụng tăng; invoice giảm paid'),
    fragment('opt','Đã thực trả và cần ghi hoàn tiền',[
        call('actor','ui','Nhập tiền hoàn và tham chiếu'),call('ui','service','refund(receiptId, amount, key)'),
        *query('TX: khóa receipt; kiểm tra availableAmount','Số dư khả dụng'),
        fragment('alt','amount <= availableAmount',[
            *query('Tạo BillingRefund; giảm available; audit','Commit hoàn sổ'),reply('service','ui','Lịch sử hoàn tiền')],alternate=('amount > availableAmount',[reply('service','ui','409; giữ nguyên số dư')]))])],
    [('billing/billing-ledger.service.ts','release'),('billing/billing-ledger.service.ts','refund')])

add('SD-08','Gửi và xét duyệt chứng từ thanh toán','Người thuê','Portal / Billing',
    'Người thuê có invoice của mình; chủ trọ xét duyệt bằng phiên có quyền riêng.',
    'PENDING không phải đã thanh toán; APPROVED tạo receipt, payment và allocation một lần.',[
    call('actor','ui','Chọn tệp và nhập tiền đã chuyển'),call('ui','service','Tải tệp qua endpoint bảo vệ'),
    *query('Lưu tệp theo policy truy cập','Định danh tệp được phép'),reply('service','ui','Thông tin tệp'),
    call('ui','service','submitPaymentProof(invoiceId, key)'),
    *query('Kiểm tra tenant, invoice, tệp; tạo PENDING','Proof chờ xét duyệt'),reply('service','ui','PENDING; chưa giảm công nợ'),
    call('second','ui','Mở proof; nhập quyết định'),call('ui','service','reviewPaymentProof(proofId, decision)'),
    *query('TX: khóa proof; kiểm tra PENDING và scope','Proof chưa được xử lý'),
    fail('Đã review hoặc ngoài scope','Không ghi thu trùng'),
    fragment('alt','APPROVED',[
        *query('Khóa invoice; kiểm tra demo, hủy, dư nợ','Invoice còn được thu'),
        fail('Proof vượt số dư mới hoặc invoice không hợp lệ','409; rollback'),
        call('service','data','Tạo receipt, payment, allocation; cập nhật invoice')],alternate=('REJECTED',[call('service','data','Chỉ ghi từ chối và lý do')])),
    reply('data','service','Commit quyết định và lịch sử'),reply('service','ui','Proof và trạng thái hóa đơn mới')],
    [('tenant-portal/tenant-portal.service.ts','submitPaymentProof'),('billing/billing.service.ts','reviewPaymentProof')],second='Chủ trọ')

add('SD-09','Thay thế hoặc điều chỉnh hóa đơn','Chủ trọ','BillingLedgerService',
    'Có invoice ngoài demo, không bị hủy; có lý do và requestKey.',
    'Replacement và adjustment là hai lựa chọn loại trừ; không ghi đè lịch sử thanh toán.',[
    call('actor','ui','Chọn loại xử lý và nhập lý do'),call('ui','service','replace() hoặc adjust()'),
    *query('TX: kiểm tra command; khóa invoice','Invoice, payment history và số dư'),
    fragment('alt','Chọn replacement',[
        fail('Có payment history hoặc đã replacement','409; dùng adjustment phù hợp'),
        *query('Hủy invoice gốc; hủy link; tạo revision và snapshot','Hóa đơn thay thế')],alternate=('Chọn adjustment',[
        call('service','service','Kiểm tra CREDIT / DEBIT và amount / basisPoints'),
        fail('Sai loại hoặc credit vượt số dư','Không ghi adjustment'),
        *query('Thêm adjustment và line item; tính lại total / status','Hóa đơn điều chỉnh')])),
    *query('Ghi event, audit và command response','Commit một nhánh duy nhất'),reply('service','ui','Invoice và timeline cập nhật'),reply('ui','actor','Hiển thị bản gốc và lịch sử liên quan')],
    [('billing/billing-ledger.service.ts','replace'),('billing/billing-ledger.service.ts','adjust')])

add('SD-10','Quyết toán trả phòng và hoàn cọc','Chủ trọ','LeaseSettlementsService',
    'Chủ trọ có lease ACTIVE chưa quyết toán; ngày trả và chỉ số hợp lệ.',
    'Confirm kết thúc lease và tạo turnover; hóa đơn cũ không tự được xóa nợ; hoàn cọc là bước ghi sổ riêng.',[
    call('actor','ui','Nhập ngày trả, chỉ số, chi phí'),call('ui','service','preview(leaseId, input)'),
    *query('Đọc lease, invoice, cọc; tính snapshot','Snapshot và previewFingerprint'),reply('service','ui','Phí, cấn trừ cọc, hoàn / còn phải thu'),
    call('actor','ui','Xác nhận quyết toán'),call('ui','service','confirm(input, fingerprint, key)'),
    *query('TX: khóa lease / room / invoice; tính lại','Snapshot hiện tại hoặc settlement cũ'),
    fragment('break','Đã có settlement',[
        reply('service','ui','Cùng key + hash: kết quả cũ; khác: 409')]),
    fail('Fingerprint đổi hoặc key đã dùng lease khác','409; yêu cầu preview lại'),
    *query('Tạo settlement / lines; cấn trừ cọc; ENDED; turnover; audit','Commit quyết toán'),reply('service','ui','Settlement; hoàn cọc chưa thực hiện'),
    fragment('opt','Có khoản hoàn và chủ trọ đã trả tiền',[
        call('actor','ui','Ghi xác nhận đã hoàn; tham chiếu'),call('ui','service','recordRefund(version, key, reference)'),
        *query('TX: khóa; kiểm tra version và số dư cọc','Trạng thái refund PENDING'),
        fail('Đã hoàn, sai version hoặc số dư đổi','409; không ghi hoàn trùng'),
        *query('Ghi REFUNDED và refundStatus PAID; audit','Commit ghi sổ hoàn cọc'),reply('service','ui','Quyết toán và lịch sử hoàn')])],
    [('leases/settlements.service.ts','preview'),('leases/settlements.service.ts','confirm'),('leases/settlements.service.ts','recordRefund')])

add('SD-11','Yêu cầu và thực thi vòng đời thuê','Người thuê','TenantLifecycleService',
    'Người thuê có lease liên quan; chủ trọ có quyền xử lý trong cùng phạm vi.',
    'APPROVED chỉ là quyết định; execute là lệnh riêng, kiểm tra lại dữ liệu và có bản ghi execution.',[
    call('actor','ui','Yêu cầu gia hạn, chuyển hoặc trả phòng'),call('ui','service','createRequest(type, lease, input)'),
    *query('Kiểm tra lease, yêu cầu PENDING trùng; lưu request','PENDING'),reply('service','ui','Yêu cầu chờ quyết định'),
    call('second','ui','Xem và quyết định; nhập lý do'),call('ui','service','decideRequest(expectedUpdatedAt)'),
    *query('TX: khóa; kiểm tra lease, đích chuyển và trạng thái','Dữ liệu hiện tại'),
    fail('Đã xử lý hoặc hợp đồng / phòng đổi','409; đọc lại yêu cầu'),
    *query('Ghi APPROVED / REJECTED và audit','Commit quyết định'),reply('service','ui','requiresLeaseAction nếu APPROVED'),
    fragment('opt','APPROVED và chủ trọ chọn execute',[
        call('second','ui','Xác nhận thực thi'),call('ui','service','executeRequest(key, expectedUpdatedAt)'),
        *query('TX: khóa request; kiểm tra execution và lease / phòng','Điều kiện và hash thực thi'),
        fail('Sai hash / stale / đích không còn trống','409; không thực thi mới'),
        *query('Gia hạn / chuyển / kết thúc; Execution và audit','Commit theo loại yêu cầu'),reply('service','ui','Kết quả execution và lease mới')])],
    [('tenant-lifecycle/tenant-lifecycle.service.ts','createRequest'),('tenant-lifecycle/tenant-lifecycle.service.ts','decideRequest'),('tenant-lifecycle/tenant-lifecycle.service.ts','executeRequest')],second='Chủ trọ')

add('SD-12','Tiếp nhận và hoàn tất yêu cầu bảo trì','Người thuê','MaintenanceService',
    'Người thuê có phòng hợp lệ; chủ trọ quản lý phạm vi của ticket.',
    'Giữ lịch sử trạng thái và trao đổi; chi phí chỉ được tạo theo dữ liệu thực tế và liên kết ticket.',[
    call('actor','ui','Gửi mô tả, ảnh sự cố'),call('ui','service','Tạo maintenance từ tenant portal'),
    *query('Kiểm tra tenant / phòng; tạo ticket','Yêu cầu bảo trì'),reply('service','ui','Ticket và trạng thái ban đầu'),
    call('second','ui','Xem ticket và phân công xử lý'),call('ui','service','assign / cập nhật ticket theo quyền'),
    *query('Kiểm tra scope, assignee và trạng thái','Ticket được cập nhật'),reply('service','ui','Phân công và lịch sử'),
    fragment('loop','Khi cần trao đổi / cập nhật tiến độ',[
        call('ui','service','Gửi comment / status'),*query('Kiểm tra quyền; lưu comment / tiến độ','Lịch sử mới'),reply('service','ui','Nội dung được phép xem')]),
    call('second','ui','Xác nhận hoàn tất và chi phí nếu có'),call('ui','service','Cập nhật DONE và dữ liệu chi phí'),
    *query('Kiểm tra trạng thái; hoàn tất, liên kết Expense nếu có','Ticket và expense hiện hành'),
    fail('Ngoài scope hoặc dữ liệu không hợp lệ','Từ chối; không báo hoàn tất'),reply('service','ui','Trạng thái hoàn tất và lịch sử')],
    [('tenant-portal/tenant-portal.service.ts','createMaintenance'),('maintenance/maintenance.service.ts','update'),('maintenance/maintenance.service.ts','updateStatus'),('maintenance/maintenance.service.ts','addComment'),('maintenance/maintenance.service.ts','complete')],second='Chủ trọ')

add('SD-13','Báo cáo tháng và xuất CSV','Chủ trọ','ReportsService',
    'Có phiên và quyền báo cáo; tháng và khu thuộc phạm vi chủ trọ.',
    'Báo cáo Payment ròng không đồng nghĩa tổng Receipt; thao tác hiện tại sao chép CSV vào clipboard.',[
    call('actor','ui','Chọn tháng và khu trọ'),call('ui','service','monthly(month, propertyId)'),
    *query('Xác minh property scope và isArchived','Khu hợp lệ hoặc không có'),
    fail('Tháng sai hoặc khu ngoài phạm vi','400 / 404; không trả số liệu'),
    *query('Đọc invoices, payments, expenses, deposits, active leases','Các tập dữ liệu theo mốc thời gian'),
    call('service','service','Tổng hợp công nợ và dòng tiền ròng'),reply('service','ui','Summary, nhóm và invoice rows'),reply('ui','actor','Hiển thị chỉ số của kỳ'),
    fragment('opt','Chọn xuất và có quyền export',[
        call('actor','ui','Chọn xuất CSV'),call('ui','service','monthlyExport(month, propertyId)'),
        *query('Chạy lại truy vấn báo cáo đúng scope','Dữ liệu tại thời điểm xuất'),call('service','service','Escape ô CSV và tạo tên file'),reply('service','ui','filename, mimeType, content'),
        call('ui','ui','Clipboard.setData(content)'),reply('ui','actor','Thông báo đã sao chép CSV')])],
    [('reports/reports.service.ts','monthly'),('reports/reports.service.ts','monthlyExport')])

add('SD-14','Đình chỉ tài khoản khách hàng','Admin','AdminConsoleService',
    'Admin có capability; đối tượng là tài khoản khách hàng, không phải tài khoản Admin.',
    'Đổi trạng thái và thu hồi phiên cùng transaction; không xóa hóa đơn / dữ liệu tài chính.',[
    call('actor','ui','Mở tài khoản; chọn đình chỉ và lý do'),call('ui','service','status(id, version, isActive=false)'),
    *query('TX: khóa User; chỉ đọc role khác ADMIN','User và sessionVersion'),
    fragment('alt','Không tìm thấy hoặc version / trạng thái đổi',[
        reply('service','ui','404 / 409; tải lại, không ghi')],alternate=('Tài khoản khách hàng hợp lệ',[
        *query('Đổi isActive; tăng sessionVersion','User mới trong transaction'),
        *query('Thu hồi sessions, refresh, access-link và phiên phụ thuộc','Số bản ghi theo policy'),
        *query('Ghi adminAudit với before / after','Commit toàn bộ hoặc rollback'),reply('service','ui','Account projection mới'),reply('ui','actor','Cập nhật danh sách và detail')])),
    fragment('opt','Khôi phục ở lần xử lý khác',[
        call('actor','ui','Chọn khôi phục và lý do'),call('ui','service','status(id, version, isActive=true)'),
        *query('Kiểm tra lại; đổi trạng thái, version; audit','Tài khoản active, token cũ vẫn thu hồi'),reply('service','ui','Trạng thái mới; cần đăng nhập phiên mới')])],
    [('admin/admin-console.service.ts','status')])

add('SD-15','Tra cứu inventory và chuyển kiểm duyệt tin','Admin','Inventory / Moderation',
    'Phiên Admin có quyền inventory; duyệt tin cần thêm capability moderation tương ứng.',
    'Inventory chỉ đọc; điều hướng tới đúng listing UUID, không sửa Room / Lease / Invoice từ card.',[
    call('actor','ui','Lọc khu / phòng và phân trang'),call('ui','service','GET admin inventory theo query'),
    *query('Kiểm tra scope; đọc projection có masking','Danh sách và meta phân trang'),reply('service','ui','Inventory cùng trạng thái listing riêng'),
    call('actor','ui','Chọn tin PENDING cần xử lý'),
    fragment('break','Không có quyền moderation',[
        reply('ui','actor','Ẩn / chặn hành động; không gửi quyết định')]),
    call('ui','service','Tìm queue theo exact listing UUID'),*query('Đọc mục kiểm duyệt và trạng thái claim','Mục tiêu chính xác'),reply('service','ui','Queue item và version'),
    call('actor','ui','Claim; nhập quyết định và lý do'),call('ui','service','Gửi claim / decision có version'),
    *query('TX: kiểm tra quyền, claim và version','Trạng thái trước khi ghi'),
    fail('Mất claim hoặc version đã đổi','409; tải lại, không áp quyết định'),
    *query('Ghi decision và audit','Commit trạng thái tin'),reply('service','ui','Kết quả kiểm duyệt'),call('ui','ui','Invalidate inventory khi quay lại')],
    [('admin/admin.service.ts','rooms'),('admin/admin-console.service.ts','work'),('listings/listings.service.ts','review'),('listings/listings.service.ts','mutate')])

add('SD-16','Đối soát khoản thu theo maker checker','Admin maker','FinanceReconciliation',
    'Hai tài khoản Admin độc lập có quyền finance; CSV sao kê hợp lệ.',
    'Checker không được là maker; đối soát receipt không nhân bản tiền theo allocation.',[
    call('actor','ui','Import sao kê và chọn dòng'),call('ui','service','importStatement(csv) / candidates(line)'),
    *query('Kiểm tra đầu vào, trùng; tìm candidate theo scope','Dòng sao kê và ứng viên'),reply('service','ui','Candidates receipt / payment legacy'),
    call('actor','ui','Đề nghị match và nhập lý do'),call('ui','service','propose(lineId, version, action)'),
    *query('TX: khóa đối soát; kiểm tra; tạo PENDING và audit','Proposal có maker và lineVersion'),reply('service','ui','Đề nghị chờ checker'),
    call('second','ui','Xem đề nghị; duyệt hoặc từ chối'),call('ui','service','review(proposalId, version, approve)'),
    *query('TX: khóa; đọc proposal và line','Proposal PENDING và version'),
    fail('Checker = maker, stale hoặc đã review','403 / 409; không tự duyệt'),
    fragment('alt','approve = true',[
        *query('Kiểm tra receipt / payment chưa match và đúng số tiền','Ứng viên còn hợp lệ'),
        fail('Ứng viên thay đổi hoặc đã ghép','409; giữ nguyên đối soát'),call('service','data','Cập nhật line, tăng version; proposal APPROVED')],alternate=('approve = false',[call('service','data','Proposal REJECTED; giữ line')])),
    reply('data','service','Commit cùng audit quyết định'),reply('service','ui','Proposal và line hiện tại')],
    [('platform/finance-reconciliation.service.ts','importStatement'),('platform/finance-reconciliation.service.ts','propose'),('platform/finance-reconciliation.service.ts','review')],second='Admin checker')

add('SD-17','Chatbot RAG và đọc nguồn theo quyền','Chủ trọ','ChatbotService',
    'Phiên LANDLORD; cấu hình AI bật; câu hỏi trong giới hạn và property thuộc chủ trọ.',
    'Chỉ trả câu trả lời có nguồn còn hiệu lực; không gọi tool lấy số liệu sống hoặc ghi dữ liệu nghiệp vụ.',[
    call('actor','ui','Nhập câu hỏi và propertyId'),call('ui','service','ask(message, scope)'),
    call('service','service','JWT / role / rate limit; scope; timeout'),
    fail('AI tắt, quá tải, timeout hoặc scope sai','Mã lỗi; UI cho thử lại phù hợp'),
    fragment('break','Hỏi số liệu hiện tại hoặc thiếu ngữ cảnh',[
        reply('service','ui','insufficient_evidence; nêu giới hạn')]),
    *query('Retriever: tìm chunks theo quyền','Tối đa nguồn trong context giới hạn'),
    fail('Không có nguồn hoặc không đủ bằng chứng','insufficient_evidence; không bịa'),
    call('service','data','Model: sinh đáp án từ chunks cho phép'),reply('data','service','Đáp án và sourceIds'),
    fragment('opt','AI_CONTEXT_LIMIT và có nhiều chunks',[
        call('service','data','Thử model lại với một chunk'),reply('data','service','Kết quả giới hạn context')]),
    call('service','service','Validate nội dung và sourceIds'),
    *query('Kiểm tra nguồn active và contentHash','Nguồn hiện hành hoặc bị thu hồi'),
    fail('Nguồn đổi / thu hồi hoặc phản hồi sai','Fallback / AI_INVALID_RESPONSE'),
    reply('service','ui','answered, answer, sources'),
    fragment('opt','Người dùng mở nguồn',[
        call('ui','service','getSource(id, scope)'),*query('Kiểm tra quyền và đọc nguồn','Nội dung được phép'),reply('service','ui','Nguồn hoặc lỗi truy cập')])],
    [('chatbot/chatbot.service.ts','ask'),('chatbot/chatbot.service.ts','answer'),('chatbot/chatbot.service.ts','getSource')],data='Kho tri thức / Model')

add('SD-18','Duyệt hồ sơ xác minh chủ trọ','Admin','AdminVerificationService',
    'Có hồ sơ PENDING liên kết ticket hỗ trợ; Admin có quyền xét duyệt.',
    'Quyết định ghi có điều kiện version và audit chứng cứ; chỉ APPROVED khi chủ trọ active và minh chứng SUPPORT_CLEAN.',[
    call('actor','ui','Mở hàng đợi và hồ sơ'),call('ui','service','list(query)'),*query('Đọc projection và phân trang','Hồ sơ cùng version'),reply('service','ui','Dữ liệu được phép xem'),
    call('actor','ui','Nhập decision, reason và version'),call('ui','service','review(id, input)'),
    *query('TX: đọc identity; khóa User, Ticket và file','Hồ sơ / chứng cứ hiện hành'),
    fail('Tự duyệt, sai version, ticket đổi hoặc không PENDING','403 / 409; đọc lại hồ sơ'),
    fragment('alt','decision = APPROVED',[
        call('service','service','Kiểm tra active, chủ ticket, merge và SUPPORT_CLEAN'),
        fail('Chủ trọ hoặc minh chứng không hợp lệ','400; không xác minh')],alternate=('REJECTED / NEEDS_INFO',[call('service','service','Giữ lý do; không xác nhận thành công')])),
    *query('updateMany theo version và PENDING; audit hash chứng cứ','Commit status và version + 1'),reply('service','ui','Quyết định và version mới'),reply('ui','actor','Làm mới hàng đợi và hồ sơ')],
    [('admin/admin-verification.service.ts','list'),('admin/admin-verification.service.ts','review')])

add('SD-19','Gán và kết thúc quyền sử dụng gói','Admin','AdminPlansService',
    'Chủ trọ active; plan active; Admin có quyền, version và lý do.',
    'Chỉ gán entitlement; financialEffect NONE; hủy gói không hoàn tiền và không xóa inventory.',[
    call('actor','ui','Chọn gói, thời hạn và lý do'),call('ui','service','assign(landlordId, versions, input)'),
    *query('TX: khóa User; SHARE plan; đọc subscription','Plan, landlord và version'),
    fail('Inactive, hết hạn hoặc version sai','400 / 404 / 409; giữ gói cũ'),
    *query('Đếm khu chưa archive và phòng active','Inventory hiện tại'),
    fail('Số khu / phòng vượt hạn mức gói','409; không xóa dữ liệu hiện có'),
    *query('Tạo / cập nhật subscription + planSnapshot','Subscription trong transaction'),
    *query('Event ASSIGNED / REASSIGNED; audit NONE','Commit entitlement'),reply('service','ui','Subscription và lịch sử'),
    fragment('opt','Admin chọn kết thúc gói ở thao tác khác',[
        call('actor','ui','Xác nhận hủy, lý do và version'),call('ui','service','cancel(subscriptionId, version)'),
        *query('TX: khóa User; kiểm tra version và còn active','Subscription hiện hành'),
        fail('Đã inactive hoặc version đổi','409; không hủy lặp'),
        *query('endsAt = now; version++; CANCELLED event; audit','Commit financialEffect NONE'),reply('service','ui','Gói hết hiệu lực; dữ liệu thuê giữ nguyên')])],
    [('admin/admin-plans.service.ts','assign'),('admin/admin-plans.service.ts','cancel')])

def save(path):
    Path(path).write_text(json.dumps(list(MODELS.values()),ensure_ascii=False,indent=2))

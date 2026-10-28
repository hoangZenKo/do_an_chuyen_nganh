import 'capture_helper.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_invoices_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_leases_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_maintenance_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_notifications_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_invoice_detail_screen.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/maintenance.dart';
import 'package:rental_room_management/models/tenant_portal.dart';
import 'file:///Users/hoang/Rental_room_management/test/features/chatbot/chatbot_test_support.dart';
class ReportTenantSession extends SessionController {
 @override SessionState build()=>SessionState.authenticated(chatSession('Nguyễn Minh Anh',role:'tenant'));
}
void main(){
 final lease=TenantPortalLease(id:'lease-report',roomId:'r101',roomName:'A101',propertyId:'p1',propertyName:'Khu trọ Minh An',propertyAddress:'Hà Đông, Hà Nội',monthlyRent:2500000,deposit:2500000,depositBalance:2500000,startDate:DateTime(2026,9,1),endDate:DateTime(2027,9,1));
 final profile=TenantPortalProfile(id:'tenant-report',fullName:'Nguyễn Minh Anh',phone:'0900000000',landlordId:'owner-report',landlordName:'Chủ trọ Minh An',activeLease:lease);
 final invoice=Invoice(id:'invoice-report',leaseId:lease.id,roomId:'r101',tenantId:profile.id,billingMonth:DateTime(2026,10),rentAmount:2500000,electricityAmount:210000,waterAmount:60000,otherAmount:100000,totalAmount:2870000,paidAmount:1000000,remainingAmount:1870000,status:InvoiceStatus.partial,roomName:'A101',propertyId:'p1',propertyName:'Khu trọ Minh An',tenantName:profile.fullName,dueDate:DateTime(2026,11,5));
 final tickets=[MaintenanceTicket(id:'m1',propertyId:'p1',roomId:'r101',status:MaintenanceStatus.inProgress,priority:MaintenancePriority.medium,title:'Kiểm tra vòi nước phòng A101',propertyName:'Khu trọ Minh An',roomName:'A101',description:'Vòi nước rò rỉ, đã tiếp nhận xử lý.',reportedAt:DateTime(2026,10,27),dueAt:DateTime(2026,10,30))];
 final notices=[TenantNotification(id:'n1',kind:'invoice',title:'Hóa đơn tháng 10 đã được lập',body:'Vui lòng kiểm tra các khoản phí và hạn thanh toán trong hóa đơn của bạn.',invoiceId:invoice.id,createdAt:DateTime(2026,10,28)),TenantNotification(id:'n2',kind:'maintenance',title:'Yêu cầu bảo trì đang được xử lý',body:'Chủ trọ đã tiếp nhận yêu cầu kiểm tra vòi nước.',maintenanceId:'m1',read:true,createdAt:DateTime(2026,10,27))];
 final dashboard=TenantDashboard(profile:profile,outstandingAmount:1870000,openInvoiceCount:1,overdueInvoiceCount:0,dueSoonInvoiceCount:1,openMaintenanceCount:1,unreadNotificationCount:1,nextInvoice:invoice,recentMaintenance:tickets);
 final screens=<String,Widget>{'tenant-overview':const TenantPortalScreen(),'tenant-invoices':const TenantInvoicesScreen(),'tenant-leases':const TenantLeasesScreen(),'tenant-maintenance':const TenantMaintenanceScreen(),'tenant-notifications':const TenantNotificationsScreen(),'tenant-invoice-detail':const TenantInvoiceDetailScreen(invoiceId:'invoice-report')};
 for(final entry in screens.entries){
 testWidgets('report ${entry.key}',(tester) async {
  tester.view.physicalSize=const Size(430,932);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await reportPumpWidget(tester,ProviderScope(overrides:[sessionControllerProvider.overrideWith(ReportTenantSession.new),tenantPortalProfileProvider.overrideWith((ref)async=>profile),tenantPortalDashboardProvider.overrideWith((ref)async=>dashboard),tenantPortalInvoicesProvider.overrideWith((ref)async=>[invoice]),tenantPortalLeasesProvider.overrideWith((ref)async=>[lease]),tenantPortalMaintenanceProvider.overrideWith((ref)async=>tickets),tenantPortalNotificationsProvider.overrideWith((ref)async=>notices),tenantPortalZaloMessagesProvider.overrideWith((ref)async=>[]),tenantPortalInvoiceProvider.overrideWith((ref,id)async=>invoice)],child:MaterialApp(debugShowCheckedModeBanner:false,theme:AppTheme.dark,home:entry.value)));
  await tester.pumpAndSettle();await reportCapture(tester,entry.key);
  expect(find.byType(Scaffold),findsWidgets);expect(tester.takeException(),isNull);
 });
 }
}

import 'capture_helper.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/login_screen.dart';
import 'package:rental_room_management/features/auth/register_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/tenants/tenants_list_screen.dart';
import 'package:rental_room_management/features/tenants/tenant_providers.dart';
import 'package:rental_room_management/features/billing/billing_screen.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/reports/reports_screen.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';
import 'package:rental_room_management/features/rooms/property_selection_provider.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/reports.dart';
import 'package:rental_room_management/models/tenant.dart';
import 'file:///Users/hoang/Rental_room_management/test/features/chatbot/chatbot_test_support.dart';
void main(){
 final invoice=Invoice.fromJson({'id':'iv1','leaseId':'l1','tenantId':'t1','roomId':'r101','roomName':'A101','tenantName':'Nguyễn Minh Anh','billingMonth':'2026-10-01','rentAmount':2500000,'electricityAmount':210000,'waterAmount':60000,'otherAmount':100000,'totalAmount':2870000,'paidAmount':1000000,'remainingAmount':1870000,'status':'partial','dueDate':'2026-11-05'});
 final report=MonthlyReport.fromJson({'month':'2026-10-01','summary':{'activeLeases':7,'invoiceCount':7,'billedAmount':20870000,'receivedAmount':19000000,'outstandingAmount':1870000,'expenseAmount':1200000,'estimatedProfit':17800000,'depositCollected':2500000,'depositReturned':0},'invoiceStatus':{'paid':6,'partial':1,'unpaid':0},'invoices':[{'id':'iv1','roomName':'A101','tenantName':'Nguyễn Minh Anh','totalAmount':2870000,'paidAmount':1000000,'remainingAmount':1870000,'status':'partial'}]});
 final screens=<String,Widget>{'public-login':const LoginScreen(),'public-register':const RegisterScreen(),'landlord-tenants':const TenantsListScreen(),'landlord-invoices':const BillingScreen(),'landlord-monthly-report':const ReportsScreen()};
 for(final entry in screens.entries){testWidgets('report ${entry.key}',(tester)async{
 tester.view.physicalSize=const Size(430,932);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
 await reportPumpWidget(tester,ProviderScope(overrides:[sessionControllerProvider.overrideWith(ChatTestSession.new),selectedPropertyProvider.overrideWith((ref)=>'p1'),tenantsProvider.overrideWith((ref)async=>[const Tenant(id:'t1',fullName:'Nguyễn Minh Anh',phone:'0900000000',activeLease:ActiveLeaseRef(id:'l1',roomId:'r101',roomName:'A101',monthlyRent:2500000)),const Tenant(id:'t2',fullName:'Trần Tuấn Anh',phone:'0900000001',activeLease:ActiveLeaseRef(id:'l2',roomId:'r102',roomName:'A102',monthlyRent:2800000))]),invoicesProvider.overrideWith((ref)async=>[invoice]),monthlyReportProvider.overrideWith((ref)async=>report),selectedReportMonthProvider.overrideWith((ref)=>DateTime(2026,10)),billingRemindersProvider.overrideWith((ref)async=>[]),billingReminderPolicyProvider.overrideWith((ref)async=>{'enabled':false,'channels':['in_app'],'daysBeforeDue':3}),pendingPaymentProofsProvider.overrideWith((ref)async=>[])],child:MaterialApp(debugShowCheckedModeBanner:false,theme:AppTheme.dark,home:Scaffold(body:entry.value))));
 await tester.pumpAndSettle();await reportCapture(tester,entry.key);expect(tester.takeException(),isNull);
 });}
}

import 'package:flutter/material.dart';
import '../../models/admin_models.dart';

class AdminDestination {
  const AdminDestination(this.path, this.label, this.icon, this.group,
      [this.permissions = const []]);
  final String path, label, group;
  final IconData icon;
  final List<String> permissions;
  bool allowed(AdminCapabilities rights) =>
      (permissions.isEmpty || permissions.any(rights.has)) &&
      (path != '/admin/landlord-verifications' ||
          rights.has('admin.support.read'));
}

const adminDestinations = [
  AdminDestination('/admin', 'Tổng quan', Icons.space_dashboard_outlined,
      'Workspace', ['admin.dashboard.view']),
  AdminDestination('/admin/operations', 'Vận hành hệ thống',
      Icons.monitor_heart_outlined, 'Workspace', ['admin.operations.view']),
  AdminDestination('/admin/notifications', 'Thông báo',
      Icons.notifications_outlined, 'Workspace', ['admin.notifications.view']),
  AdminDestination('/admin/support-center', 'Support Center',
      Icons.support_agent_outlined, 'Hỗ trợ', ['admin.support.read']),
  AdminDestination('/admin/support', 'Tra cứu hỗ trợ',
      Icons.manage_search_outlined, 'Hỗ trợ', ['admin.support.read']),
  AdminDestination('/admin/search', 'Tra cứu toàn hệ thống',
      Icons.search_outlined, 'Hỗ trợ', ['admin.dashboard.view']),
  AdminDestination('/admin/accounts', 'Tài khoản', Icons.people_outline,
      'Dữ liệu', ['admin.accounts.view']),
  AdminDestination('/admin/landlords', 'Chủ trọ', Icons.person_outline,
      'Dữ liệu', ['admin.accounts.manage']),
  AdminDestination('/admin/properties', 'Khu trọ', Icons.apartment_outlined,
      'Dữ liệu', ['admin.properties.view']),
  AdminDestination('/admin/rooms', 'Phòng', Icons.meeting_room_outlined,
      'Dữ liệu', ['admin.properties.view']),
  AdminDestination('/admin/landlord-verifications', 'Xác minh chủ trọ',
      Icons.verified_user_outlined, 'Kiểm duyệt', ['admin.verifications.view']),
  AdminDestination(
      '/admin/property-reviews',
      'Duyệt khu trọ',
      Icons.domain_verification_outlined,
      'Kiểm duyệt',
      ['admin.properties.view']),
  AdminDestination('/admin/service-plans', 'Gói dịch vụ', Icons.layers_outlined,
      'Tài chính & báo cáo', ['admin.plans.view']),
  AdminDestination('/admin/subscriptions', 'Đăng ký dịch vụ',
      Icons.assignment_outlined, 'Tài chính & báo cáo', ['admin.plans.view']),
  AdminDestination(
      '/admin/moderation',
      'Công việc kiểm duyệt',
      Icons.fact_check_outlined,
      'Kiểm duyệt',
      ['admin.listings.moderate', 'admin.reviews.moderate']),
  AdminDestination('/admin/moderation-v2', 'Moderation v2',
      Icons.rule_folder_outlined, 'Kiểm duyệt', [
    'admin.moderation.reports',
    'admin.moderation.appeals',
    'admin.moderation.bulk'
  ]),
  AdminDestination('/admin/moderation-policies', 'Policy kiểm duyệt',
      Icons.policy_outlined, 'Kiểm duyệt', ['admin.moderation.reports']),
  AdminDestination(
      '/admin/finance-reconciliation',
      'Đối soát chỉ đọc',
      Icons.account_balance_outlined,
      'Tài chính & báo cáo',
      ['admin.finance.read']),
  AdminDestination('/admin/report-schedules', 'Báo cáo định kỳ',
      Icons.schedule_outlined, 'Tài chính & báo cáo', ['admin.reports.manage']),
  AdminDestination('/admin/reports/overview', 'Báo cáo tổng quan',
      Icons.bar_chart_rounded, 'Tài chính & báo cáo', ['admin.dashboard.view']),
  AdminDestination('/admin/governance', 'Governance',
      Icons.account_tree_outlined, 'Quản trị', ['admin.flags.manage']),
  AdminDestination('/admin/admins', 'Nhân sự admin',
      Icons.admin_panel_settings_outlined, 'Quản trị', ['admin.admins.manage']),
  AdminDestination('/admin/teams', 'Nhóm admin', Icons.groups_outlined,
      'Quản trị', ['admin.teams.manage']),
  AdminDestination('/admin/permission-simulator', 'Mô phỏng quyền',
      Icons.policy_outlined, 'Quản trị', ['admin.permissions.simulate']),
  AdminDestination('/admin/audit-logs', 'Nhật ký', Icons.history, 'Quản trị',
      ['admin.audit.view']),
  AdminDestination(
      '/admin/security', 'Bảo mật', Icons.security_outlined, 'Quản trị'),
  AdminDestination('/admin/sessions', 'Thiết bị đăng nhập',
      Icons.devices_outlined, 'Quản trị'),
];

AdminDestination? adminDestinationFor(String path) {
  final normalized = switch (path) {
    '/admin/tickets' => '/admin/support-center',
    '/admin/reports' => '/admin/report-schedules',
    _ => path,
  };
  return adminDestinations
      .where((entry) =>
          entry.path == normalized ||
          (entry.path != '/admin' && normalized.startsWith('${entry.path}/')))
      .firstOrNull;
}

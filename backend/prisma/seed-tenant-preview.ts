import 'dotenv/config';
import { createHash } from 'node:crypto';
import {
  InvoiceStatus,
  LeaseStatus,
  MaintenancePriority,
  MaintenanceStatus,
  NotificationDeliveryChannel,
  NotificationDeliveryStatus,
  PaymentMethod,
  PrismaClient,
  UserRole,
} from '@prisma/client';

const prisma = new PrismaClient();
const marker = '[tenant-preview]';

function previewId(key: string) {
  const digest = createHash('sha256').update(`${marker}:${key}`).digest('hex');
  return `${digest.slice(0, 8)}-${digest.slice(8, 12)}-4${digest.slice(13, 16)}-a${digest.slice(17, 20)}-${digest.slice(20, 32)}`;
}

async function main() {
  const database = new URL(process.env.DATABASE_URL ?? '');
  if (
    process.env.NODE_ENV === 'production' ||
    !['localhost', '127.0.0.1', '[::1]'].includes(database.hostname)
  ) {
    throw new Error('Tenant preview data may only be added to a local database.');
  }

  const account = await prisma.user.findUnique({
    where: { email: 'tenant@demo.com' },
    include: {
      tenantProfile: {
        include: {
          leases: {
            where: { status: LeaseStatus.ACTIVE },
            include: { room: true },
          },
        },
      },
    },
  });
  const tenant = account?.tenantProfile;
  const lease = tenant?.leases[0];
  if (account?.role !== UserRole.TENANT || !tenant || !lease) {
    throw new Error('Activate tenant@demo.com and its demo lease before seeding.');
  }

  const localDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  const [year, month, day] = localDate.split('-').map(Number);
  const date = (monthOffset: number, dayOfMonth: number) =>
    new Date(Date.UTC(year, month - 1 + monthOffset, dayOfMonth, 5));
  const scope = `${tenant.id}:${year}-${month}`;

  const result = await prisma.$transaction(async (transaction) => {
    const invoices = [];
    for (const sample of [
      { offset: -3, electricity: 245000, water: 80000, paid: true, partial: false },
      { offset: -1, electricity: 315000, water: 100000, paid: false, partial: true },
      { offset: 0, electricity: 280000, water: 90000, paid: false, partial: false },
    ]) {
      const totalAmount = lease.monthlyRent + sample.electricity + sample.water + 150000;
      const paidAmount = sample.paid ? totalAmount : sample.partial ? 2500000 : 0;
      const invoice = await transaction.invoice.upsert({
        where: {
          leaseId_billingMonth_isDemo_revision: { leaseId: lease.id, billingMonth: date(sample.offset, 1), isDemo: true, revision: 1 },
        },
        update: {},
        create: {
          id: previewId(`${scope}:invoice:${sample.offset}`),
          leaseId: lease.id,
          roomId: lease.roomId,
          tenantId: tenant.id,
          billingMonth: date(sample.offset, 1),
          issuedAt: date(sample.offset, 1),
          dueDate: sample.offset === 0 ? date(0, day + 5) : date(sample.offset, 5),
          rentAmount: lease.monthlyRent,
          electricityAmount: sample.electricity,
          waterAmount: sample.water,
          otherAmount: 150000,
          totalAmount,
          isDemo: true,
          paidAmount,
          status: sample.paid ? InvoiceStatus.PAID : sample.partial ? InvoiceStatus.PARTIAL : InvoiceStatus.UNPAID,
          note: `${marker} Điện 3.500 đ/kWh; nước 20.000 đ/m³; Internet và vệ sinh 150.000 đ. Dữ liệu mẫu local.`,
          payments: paidAmount > 0 ? {
            create: {
              amount: paidAmount,
              method: PaymentMethod.BANK_TRANSFER,
              paidAt: date(sample.offset, 3),
              note: `${marker} Khoản thanh toán mô phỏng, không chuyển tiền thật.`,
            },
          } : undefined,
        },
      });
      invoices.push(invoice.id);
    }

    const tickets = [];
    for (const [index, sample] of [
      { title: 'Vòi nước nhà tắm bị rò rỉ', description: 'Nước nhỏ giọt liên tục ở đầu nối vòi sen. Nhờ chủ trọ kiểm tra giúp.', status: MaintenanceStatus.OPEN, priority: MaintenancePriority.URGENT, reply: 'Mình đã nhận thông tin, thợ sẽ liên hệ để hẹn giờ kiểm tra.' },
      { title: 'Máy lạnh làm mát yếu', description: 'Máy lạnh chạy nhưng phòng không mát, cần vệ sinh và kiểm tra gas.', status: MaintenanceStatus.IN_PROGRESS, priority: MaintenancePriority.MEDIUM, reply: 'Đã đặt lịch thợ lúc 14:00 ngày mai. Em sắp xếp có mặt tại phòng nhé.' },
      { title: 'Thay bóng đèn ban công', description: 'Bóng đèn ban công chập chờn, đã được thay mới và hoạt động bình thường.', status: MaintenanceStatus.DONE, priority: MaintenancePriority.LOW, reply: 'Đã thay bóng đèn mới. Em kiểm tra lại và báo nếu cần hỗ trợ thêm nhé.' },
    ].entries()) {
      const reportedAt = date(0, day - index - 2);
      const ticket = await transaction.maintenanceTicket.upsert({
        where: { id: previewId(`${scope}:ticket:${index}`) },
        update: {},
        create: {
          id: previewId(`${scope}:ticket:${index}`),
          landlordId: tenant.landlordId,
          propertyId: lease.room.propertyId,
          roomId: lease.roomId,
          title: sample.title,
          description: sample.description,
          status: sample.status,
          priority: sample.priority,
          reportedAt,
          createdAt: reportedAt,
          startedAt: index > 0 ? reportedAt : null,
          completedAt: index === 2 ? date(0, day - 1) : null,
          note: `${marker} Yêu cầu sửa chữa mẫu local.`,
          comments: {
            create: {
              authorId: tenant.landlordId,
              authorRole: UserRole.LANDLORD,
              body: sample.reply,
            },
          },
        },
      });
      tickets.push(ticket.id);
    }

    for (const [index, message] of [
      'Chào em, hóa đơn tháng này đã có. Em kiểm tra chi tiết tiền phòng, điện nước và gửi chứng từ khi thanh toán nhé. Đây là tin nhắn mẫu local.',
      'Chủ trọ đã nhận yêu cầu sửa chữa. Em theo dõi tiến độ ở mục Sửa chữa và phản hồi thời gian thuận tiện nhé. Đây là tin nhắn mẫu local.',
    ].entries()) {
      await transaction.notificationDelivery.upsert({
        where: { id: previewId(`${scope}:message:${index}`) },
        update: {},
        create: {
          id: previewId(`${scope}:message:${index}`),
          landlordId: tenant.landlordId,
          tenantId: tenant.id,
          channel: NotificationDeliveryChannel.ZALO,
          purpose: 'tenant_preview_local',
          recipient: tenant.phone ?? 'local-preview',
          status: NotificationDeliveryStatus.SKIPPED,
          payload: {
            message_text: message,
            tenant_name: tenant.fullName,
            room_name: lease.room.name,
            sender_role: 'landlord',
            direction: 'landlord_to_tenant',
            preview: true,
          },
        },
      });
    }

    return { invoices: invoices.length, maintenance: tickets.length, messages: 2 };
  });

  console.log(JSON.stringify({ account: account.email, room: lease.room.name, localDate, previewRecords: result }));
}

main()
  .catch((error: Error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

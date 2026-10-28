import { BadRequestException } from '@nestjs/common';
import { Invoice, InvoiceLineItem, MeterReading } from '@prisma/client';

import { effectiveFee } from '../rooms/service-tariff';

type Line = Omit<InvoiceLineItem, 'id' | 'invoiceId'>;
type Fee = NonNullable<ReturnType<typeof effectiveFee>>;

export function buildInvoiceLines(
  lease: { id: string; monthlyRent: number },
  readings: MeterReading[], fees: Fee[], otherAmount = 0,
) {
  const lines: Line[] = [];
  const add = (line: Omit<Line, 'position'>) => {
    if (![line.amount, line.unitPrice, line.quantity].every((value) => Number.isSafeInteger(value) && value >= 0 && value <= 2_147_483_647)
      || line.quantity * line.unitPrice !== line.amount) {
      throw new BadRequestException({ error: { code: 'INVALID_INVOICE_AMOUNT', message: 'Invoice amounts must be non-negative integers within the supported range.' } });
    }
    lines.push({ ...line, position: lines.length });
  };
  add({ kind: 'RENT', description: 'Tiền phòng', quantity: 1, unit: 'thang', unitPrice: lease.monthlyRent, amount: lease.monthlyRent, source: 'LEASE', sourceId: lease.id, tariffVersionId: null, tariffVersion: null });
  for (const reading of [...readings].sort((left, right) => left.utilityType.localeCompare(right.utilityType))) {
    add({ kind: reading.utilityType, description: reading.utilityType === 'ELECTRICITY' ? 'Tiền điện' : 'Tiền nước', quantity: reading.usage, unit: reading.utilityType === 'ELECTRICITY' ? 'kWh' : 'm3', unitPrice: reading.unitPrice, amount: reading.amount, source: 'METER_READING', sourceId: reading.id, tariffVersionId: null, tariffVersion: null });
  }
  for (const fee of fees) {
    add({ kind: 'SERVICE', description: fee.name, quantity: 1, unit: fee.unit, unitPrice: fee.amount, amount: fee.amount, source: fee.source ?? 'SERVICE_TARIFF', sourceId: fee.id, tariffVersionId: fee.tariffVersionId, tariffVersion: fee.tariffVersion });
  }
  if (otherAmount) add({ kind: 'OTHER', description: 'Phí khác', quantity: 1, unit: 'lan', unitPrice: otherAmount, amount: otherAmount, source: 'MANUAL', sourceId: null, tariffVersionId: null, tariffVersion: null });
  const totalFor = (kinds: string[]) => lines.filter((line) => kinds.includes(line.kind)).reduce((sum, line) => sum + line.amount, 0);
  const totalAmount = lines.reduce((sum, line) => sum + line.amount, 0);
  if (totalAmount > 2_147_483_647) throw new BadRequestException({ error: { code: 'INVALID_INVOICE_AMOUNT', message: 'Invoice total exceeds the supported range.' } });
  return { lines, rentAmount: totalFor(['RENT']), electricityAmount: totalFor(['ELECTRICITY']), waterAmount: totalFor(['WATER']), otherAmount: totalFor(['SERVICE', 'OTHER']), totalAmount };
}

export function serializeInvoiceLines(invoice: Pick<Invoice, 'id' | 'rentAmount' | 'electricityAmount' | 'waterAmount' | 'otherAmount'> & { lineItems?: InvoiceLineItem[] }) {
  const lines = invoice.lineItems?.length ? invoice.lineItems : [
    ['RENT', 'Tiền phòng', invoice.rentAmount], ['ELECTRICITY', 'Tiền điện', invoice.electricityAmount],
    ['WATER', 'Tiền nước', invoice.waterAmount], ['OTHER', 'Phí khác (dữ liệu cũ)', invoice.otherAmount],
  ].filter((entry) => entry[2] !== 0).map((entry, position) => ({
    id: `${invoice.id}:legacy:${position}`, invoiceId: invoice.id, position, kind: entry[0] as string,
    description: entry[1] as string, quantity: 1, unit: 'lan', unitPrice: entry[2] as number,
    amount: entry[2] as number, source: 'LEGACY', sourceId: null, tariffVersionId: null, tariffVersion: null,
  }));
  return [...lines].sort((left, right) => left.position - right.position).map((line) => ({
    ...line, kind: line.kind.toLowerCase(), source: line.source.toLowerCase(),
  }));
}

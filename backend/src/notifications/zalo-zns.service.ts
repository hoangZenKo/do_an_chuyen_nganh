import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

export type ZaloZnsSendInput = {
  phone: string;
  templateId: string;
  templateData: Record<string, string | number | null>;
  trackingId: string;
};

export type ZaloZnsSendResult = {
  ok: boolean;
  providerMessageId?: string | null;
  errorCode?: string | null;
  errorMessage?: string | null;
  raw?: unknown;
};

@Injectable()
export class ZaloZnsService {
  constructor(private readonly config: ConfigService) {}

  get enabled() {
    return this.config.get<string>("ZALO_ZNS_ENABLED") === "true";
  }

  get invoiceReminderTemplateId() {
    return (
      this.config
        .get<string>("ZALO_ZNS_INVOICE_REMINDER_TEMPLATE_ID")
        ?.trim() || null
    );
  }

  async sendTemplate(input: ZaloZnsSendInput): Promise<ZaloZnsSendResult> {
    const accessToken = this.config
      .get<string>("ZALO_ZNS_ACCESS_TOKEN")
      ?.trim();
    if (!this.enabled) {
      return {
        ok: false,
        errorCode: "ZALO_ZNS_DISABLED",
        errorMessage: "Zalo ZNS delivery is disabled.",
      };
    }
    if (!accessToken) {
      return {
        ok: false,
        errorCode: "ZALO_ZNS_ACCESS_TOKEN_MISSING",
        errorMessage: "ZALO_ZNS_ACCESS_TOKEN is missing.",
      };
    }

    const url =
      this.config.get<string>("ZALO_ZNS_SEND_URL")?.trim() ||
      "https://business.openapi.zalo.me/message/template";
    const timeoutMs = Number(
      this.config.get<string>("ZALO_ZNS_TIMEOUT_MS") ?? 10_000,
    );
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          access_token: accessToken,
        },
        body: JSON.stringify({
          phone: input.phone,
          template_id: input.templateId,
          template_data: input.templateData,
          tracking_id: input.trackingId,
        }),
        signal: controller.signal,
      });
      const raw = await response.json().catch(() => null);
      const data =
        raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
      const providerError = data.error;
      const ok = response.ok && (providerError === 0 || providerError === "0");
      const nestedData =
        data.data && typeof data.data === "object"
          ? (data.data as Record<string, unknown>)
          : {};
      return {
        ok,
        providerMessageId:
          this.asString(nestedData.msg_id) ??
          this.asString(nestedData.message_id) ??
          this.asString(data.message_id),
        errorCode: ok
          ? null
          : (this.asString(providerError) ?? response.status.toString()),
        errorMessage: ok
          ? null
          : this.asString(data.message) ||
            response.statusText ||
            "Zalo ZNS request failed.",
        raw,
      };
    } catch (error) {
      return {
        ok: false,
        errorCode:
          error instanceof Error && error.name === "AbortError"
            ? "ZALO_ZNS_TIMEOUT"
            : "ZALO_ZNS_REQUEST_FAILED",
        errorMessage:
          error instanceof Error ? error.message : "Zalo ZNS request failed.",
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  private asString(value: unknown) {
    if (value === null || value === undefined) return null;
    return String(value);
  }
}

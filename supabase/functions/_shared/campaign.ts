// supabase/functions/_shared/campaign.ts
// Purpose: 「5/31まで全ユーザー無料開放」特別企画の共有定義。
//
// 設計方針:
//  - キャンペーン期間中は Pro 相当として全員に要約機能を開放する。
//  - ただし OpenAI 課金の暴走を防ぐため、"無制限" にはしない。
//    濫用対策として日次 / 月間の安全キャップは必ず残す。
//  - キャンペーン終了後は自動的に通常リミットに戻る(コード変更不要)。
//
// End date: 2026-06-01T00:00:00+09:00 (JST)
//   → 日本時間 6/1 になった瞬間に通常モードへ戻る。
//
// 500 ユーザー × 複数デバイスで走ることを想定した数値:
//   campaign daily  : 50 件 / 日 / user   (通常 20)
//   campaign monthly: 1500 件 / 月 / user (通常 400)
// これでも 1 user が月 1500 件フルに使い切ると gpt-5-nano で
// 数ドル程度。500 user 全員がフル使用する確率は低いので、
// 予測可能なレンジに収まる。

export const CAMPAIGN_END_ISO = "2026-06-01T00:00:00+09:00";

export interface Limits {
  daily: number;
  monthly: number;
  campaignActive: boolean;
  campaignEndsAt: string;
}

export function isCampaignActive(now: Date = new Date()): boolean {
  return now.getTime() < new Date(CAMPAIGN_END_ISO).getTime();
}

export function getLimits(now: Date = new Date()): Limits {
  const active = isCampaignActive(now);
  return {
    daily: active ? 50 : 20,
    monthly: active ? 1500 : 400,
    campaignActive: active,
    campaignEndsAt: CAMPAIGN_END_ISO,
  };
}

// Rate limit error body — returned as 429 so clients can show
// "あと N 件 / resetAt まで待ってね" という正確な案内ができる。
export interface RateLimitInfo {
  error: string;
  scope: "daily" | "monthly";
  limit: number;
  used: number;
  remaining: number;
  resetAt: string;
  campaignActive: boolean;
  campaignEndsAt: string;
}

export function buildRateLimitBody(
  scope: "daily" | "monthly",
  limit: number,
  used: number,
  resetAt: Date,
  limits: Limits,
): RateLimitInfo {
  return {
    error:
      scope === "daily"
        ? "Daily limit reached. Try again tomorrow."
        : "Monthly limit reached. Please wait until next month.",
    scope,
    limit,
    used,
    remaining: Math.max(0, limit - used),
    resetAt: resetAt.toISOString(),
    campaignActive: limits.campaignActive,
    campaignEndsAt: limits.campaignEndsAt,
  };
}

// app/api/create-checkout-session/route.ts
// 個人向け Stripe 課金は現在無効。B2B 組織経由でのみ Pro 付与。
// 過去の実装は git 履歴を参照。

import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function POST() {
  return NextResponse.json({ error: "billing_disabled" }, { status: 503 });
}

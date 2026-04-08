// app/api/create-portal-session/route.ts
// 個人向け Stripe 課金は現在無効。
// 過去の実装は git 履歴を参照。

import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function POST() {
  return NextResponse.json({ error: "billing_disabled" }, { status: 503 });
}

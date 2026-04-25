// This file configures the initialization of Sentry on the server.
// The config you add here will be used whenever the server handles a request.
// https://docs.sentry.io/platforms/javascript/guides/nextjs/

import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: "https://cc46d9bd288bc33d3d8b1a96f628c831@o4511258720665600.ingest.us.sentry.io/4511258783645696",

  // Dev で起きる ENOENT (Next.js の build artifact 探索) が prod issue 一覧に
  // 流れ込むのを防ぐため、本番のみ有効化する。Vercel ビルドは NODE_ENV=production。
  enabled: process.env.NODE_ENV === 'production',

  // Define how likely traces are sampled. Adjust this value in production, or use tracesSampler for greater control.
  tracesSampleRate: 1,

  // Enable logs to be sent to Sentry
  enableLogs: true,

  // FERPA: 自動 PII 送出は無効化。ユーザー紐付けは setUser で明示的に行う。
  sendDefaultPii: false,
});

// This file configures the initialization of Sentry on the client.
// The added config here will be used whenever a users loads a page in their browser.
// https://docs.sentry.io/platforms/javascript/guides/nextjs/

import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: "https://cc46d9bd288bc33d3d8b1a96f628c831@o4511258720665600.ingest.us.sentry.io/4511258783645696",

  // Replay は学生招待フォーム等に突っ込むので、FERPA 観点で全テキスト/メディアをマスク。
  // エラー発生時のみ録画 (session sampling は 0)。
  integrations: [
    Sentry.replayIntegration({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],

  tracesSampleRate: 1,
  enableLogs: true,
  replaysSessionSampleRate: 0,
  replaysOnErrorSampleRate: 1.0,

  // FERPA: 学生の IP / user-agent 等は自動送信しない。
  // ユーザー紐付けは SentrySDK.setUser で個別注入方針。
  sendDefaultPii: false,
});

export const onRouterTransitionStart = Sentry.captureRouterTransitionStart;

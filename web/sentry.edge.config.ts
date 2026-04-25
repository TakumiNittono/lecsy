// This file configures the initialization of Sentry for edge features (middleware, edge routes, and so on).
// The config you add here will be used whenever one of the edge features is loaded.
// Note that this config is unrelated to the Vercel Edge Runtime and is also required when running locally.
// https://docs.sentry.io/platforms/javascript/guides/nextjs/

import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: "https://cc46d9bd288bc33d3d8b1a96f628c831@o4511258720665600.ingest.us.sentry.io/4511258783645696",

  // Dev では Sentry を完全 OFF。本番のみ有効。
  enabled: process.env.NODE_ENV === 'production',

  // Define how likely traces are sampled. Adjust this value in production, or use tracesSampler for greater control.
  tracesSampleRate: 1,

  // Enable logs to be sent to Sentry
  enableLogs: true,

  // FERPA: 自動 PII 送出は無効化。
  sendDefaultPii: false,
});

-- B2C Stripe Checkout の UI 露出を remote control するための feature flag。
-- 2026-06-01 ローンチ時は B2B のみ Deepgram Pro を提供。B2C は WhisperKit Free。
-- ローンチ後に個人有料プランを解放するタイミングで、Supabase Dashboard から
--   update public.feature_flags set enabled = true where name = 'b2c_stripe_checkout';
-- を叩けば iOS / Web の View Plans / Manage Subscription 導線が有効化される。

insert into public.feature_flags (name, enabled)
values ('b2c_stripe_checkout', false)
on conflict (name) do nothing;

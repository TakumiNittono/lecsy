-- subscriptions に price_lookup_key を追加 (Rev.2 plan判定用)
-- 参照: Deepgram/価格設計_現行.md Rev.2
--
-- Stripe Price の lookup_key をコピーして保存し、Edge Functionが
-- lecsy_pro_*, lecsy_student_*, lecsy_power_* で plan 判定できるようにする。

alter table public.subscriptions
  add column if not exists price_lookup_key text;

create index if not exists idx_subscriptions_price_lookup
  on public.subscriptions (price_lookup_key)
  where price_lookup_key is not null;

comment on column public.subscriptions.price_lookup_key is
  'Stripe Price lookup_key (e.g. lecsy_pro_monthly). Used by Edge Functions for plan-aware cap enforcement.';

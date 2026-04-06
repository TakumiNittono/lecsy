# Lecsy Subprocessors

**Last updated:** 2026-04-06

This page lists all subprocessors that Lecsy uses to provide its Services. Customers will be notified at least 30 days before adding a new subprocessor.

| Subprocessor | Service Provided | Data Processed | Location | Compliance |
|---|---|---|---|---|
| **Supabase, Inc.** | Database (Postgres), Auth, Storage, Edge Functions | All Customer Data | US (default), EU (Enterprise opt-in) | SOC 2 Type II, HIPAA-eligible |
| **OpenAI, L.L.C.** | AI summarization, glossary generation, cross-language summary | Transcript text submitted to AI features | US | SOC 2 Type II, GDPR DPA available |
| **Stripe, Inc.** | Payment processing, invoicing, subscription management | Billing contact info, payment method (handled by Stripe) | US, EU | PCI DSS Level 1, SOC 1/2 |
| **Vercel, Inc.** | Web hosting (Lecsy web administration console and marketing site) | Page visit logs, no Customer Data persistence | US, global edge | SOC 2 Type II |
| **Cloudflare, Inc.** | CDN, WAF, DDoS protection | Traffic metadata | US, global edge | SOC 2 Type II, ISO 27001 |
| **Sentry (Functional Software, Inc.)** | Error monitoring | Error stack traces (PII scrubbed before transmission) | US | SOC 2 Type II, GDPR DPA |
| **Resend, Inc.** | Transactional email | Recipient email, message content | US | SOC 2 Type II in progress |
| **Apple, Inc.** | App Store distribution, push notifications | Device tokens (push), App Store transaction data | US | n/a (platform provider) |

## Discontinued Subprocessors

None to date.

## Subprocessor Change Notification

To receive notifications of subprocessor changes, organization owners can subscribe at `https://lecsy.app/subprocessors-rss` or by emailing `legal@lecsy.app`.

## Customer Right to Object

Customers may object to a new subprocessor on reasonable grounds (e.g., security, compliance) within 30 days of notification. If the parties cannot resolve the objection, Customer may terminate the affected portion of the Services without penalty.

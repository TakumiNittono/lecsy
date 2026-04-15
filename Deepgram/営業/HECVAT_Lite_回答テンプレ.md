# HECVAT Lite 回答テンプレ（lecsy）

> 最終更新: 2026-04-14
> 目的: 米大学IT部門のHECVAT Lite質問への即答テンプレ。全営業面談で必要になる
> 関連: [[Deepgram-only設計_2026]] / [[_営業プレイブック共通]]

---

## このテンプレの使い方

1. 大学から HECVAT Lite が送られてきたら、このテンプレをExcel/Wordに転記
2. 学校固有の数値（席数・期間等）だけ書き換えて返送
3. 「Not Applicable」回答は **必ず理由を1行添える**（IT審査員が安心する）

---

## 0. 会社情報セクション

| 項目 | 回答 |
|------|------|
| Vendor Name | Lecsy LLC |
| Founder/CEO | Takumi Nittono |
| Founded | 2026 |
| HQ Address | [LLC設立後に確定 / Florida] |
| Website | https://lecsy.app |
| Privacy Officer | Takumi Nittono (founder@lecsy.app) |
| Security Officer | Takumi Nittono (founder@lecsy.app) |
| Employees | 1 (founder), expanding 2026-2027 |
| Customers | Pilot phase, [N] institutions |

---

## 1. Documentation セクション

| # | 質問 | 回答 |
|---|------|------|
| 1.1 | Privacy Policy URL | https://lecsy.app/privacy |
| 1.2 | Terms of Service URL | https://lecsy.app/terms |
| 1.3 | Most recent third-party security audit | None to date. SOC 2 Type II in preparation, target 2027-Q1 |
| 1.4 | Penetration test report | None to date. Annual third-party pentest planned 2026-Q4 |
| 1.5 | Business continuity / disaster recovery plan | Documented; available under NDA |
| 1.6 | Cyber liability insurance | Planned $1M coverage prior to first paid contract |

---

## 2. Company Overview

| # | 質問 | 回答 |
|---|------|------|
| 2.1 | Hosting provider | Supabase (built on AWS us-east-1) |
| 2.2 | Subprocessors | **Deepgram, Inc.** (speech-to-text, US, SOC 2 Type II), **Supabase** (database/auth/storage, US), **Apple, Inc.** (iOS platform/IAP), **Stripe, Inc.** (payment processing) |
| 2.3 | Subprocessor list maintained at | https://lecsy.app/subprocessors |
| 2.4 | Will you notify customer of subprocessor changes? | Yes, 30 days advance notice via email |

---

## 3. Application & Service Security

| # | 質問 | 回答 |
|---|------|------|
| 3.1 | Authentication mechanism | Email/password + Sign in with Apple. SAML/SSO planned for Enterprise (2026-Q4) |
| 3.2 | Multi-factor authentication | Available via Sign in with Apple (Apple-side MFA) |
| 3.3 | Password policy | Min 12 chars, complexity enforced. Bcrypt hashing |
| 3.4 | Session timeout | 30 days idle, configurable for Enterprise |
| 3.5 | Role-based access control | Yes — student / teacher / org admin / super admin roles |
| 3.6 | Audit logging | Yes — Supabase audit logs, retained 90 days. Extended retention available for Enterprise |

---

## 4. Authentication, Authorization & Accounting

| # | 質問 | 回答 |
|---|------|------|
| 4.1 | SSO support | SAML 2.0 planned 2026-Q4. Currently Apple/Google OAuth |
| 4.2 | Account provisioning | Manual email invite, CSV bulk import, planned SCIM |
| 4.3 | Account deprovisioning | Org admin can deactivate; auto-purge after contract termination + 30 days |
| 4.4 | Privileged access management | Founder is sole privileged user; access logged and reviewed monthly |

---

## 5. Data セクション（最重要）

| # | 質問 | 回答 |
|---|------|------|
| 5.1 | What data is collected from end users? | (a) Authentication: email, name. (b) Usage: minutes used per day, language. (c) Content: **transcribed text only — audio is never stored** |
| 5.2 | Is audio data stored? | **No**. Audio is streamed to Deepgram for transcription and immediately discarded. lecsy servers receive only the resulting text |
| 5.3 | Data classification (e.g., FERPA, HIPAA, PCI) | FERPA-relevant (education records). Not HIPAA. PCI handled by Stripe (PCI Level 1) |
| 5.4 | Data residency | United States (AWS us-east-1 via Supabase) |
| 5.5 | Encryption in transit | TLS 1.2+ enforced |
| 5.6 | Encryption at rest | AES-256 (Supabase default, AWS-managed keys) |
| 5.7 | Encryption key management | AWS KMS (Supabase-managed). Customer-managed keys (BYOK) available for Enterprise |
| 5.8 | Data retention | Text transcripts: indefinite until user/org deletion. Usage logs: 90 days. Audio: never stored |
| 5.9 | Data deletion SLA on contract termination | 30 days for full purge from production. 90 days for backup expiration |
| 5.10 | Right to data export | Yes — JSON / TXT / SRT / VTT / PDF exports available anytime |
| 5.11 | Right to data deletion | Yes — user-initiated immediate deletion; org-admin bulk deletion |
| 5.12 | Data minimization | Yes — only minimum required for service. No tracking pixels, no behavioral profiling |

---

## 6. Database セクション

| # | 質問 | 回答 |
|---|------|------|
| 6.1 | Database technology | PostgreSQL (Supabase managed) |
| 6.2 | Database access controls | Row-Level Security (RLS) enforced; founder-only direct DB access |
| 6.3 | Database encryption | AES-256 at rest, TLS in transit |
| 6.4 | Backup frequency | Daily automated backups, 7-day point-in-time recovery |
| 6.5 | Backup encryption | Yes, AES-256 |
| 6.6 | Backup retention | 7 days PITR + monthly snapshots for 1 year |

---

## 7. Operational Security

| # | 質問 | 回答 |
|---|------|------|
| 7.1 | Vulnerability scanning | Automated dependency scanning via GitHub Dependabot |
| 7.2 | Patch management SLA | Critical: 24h, High: 7d, Medium: 30d |
| 7.3 | Logging and monitoring | Supabase logs + Deepgram dashboard + Slack alerts on anomalies |
| 7.4 | Incident response plan | Documented; founder-led. Customer notification within 72 hours |
| 7.5 | Endpoint protection | Founder workstation: macOS with FileVault, automatic updates, password manager |

---

## 8. Network Security

| # | 質問 | 回答 |
|---|------|------|
| 8.1 | Firewall / network segmentation | Supabase-managed (VPC isolation) |
| 8.2 | DDoS protection | AWS Shield Standard via Supabase |
| 8.3 | API rate limiting | Yes — per-user and per-org rate limits enforced at Edge Function layer |
| 8.4 | Public-facing endpoints | iOS app, web app, Stripe webhook, Supabase REST/GraphQL (RLS-protected) |

---

## 9. Application Security

| # | 質問 | 回答 |
|---|------|------|
| 9.1 | OWASP Top 10 review | Conducted at design; periodic review planned |
| 9.2 | Code review process | Founder-reviewed (solo). Pair-review with Claude Code AI assistant |
| 9.3 | Static code analysis | SwiftLint + ESLint; planned addition of Snyk |
| 9.4 | Secret management | Supabase Secrets / Apple Keychain. No secrets in source code |
| 9.5 | Mobile app security | App Transport Security enforced; certificate pinning planned |

---

## 10. Privacy

| # | 質問 | 回答 |
|---|------|------|
| 10.1 | FERPA compliance | Yes by design. Audio never stored. Text encrypted, deletable. FERPA DPA available |
| 10.2 | COPPA compliance | Yes — service not directed at children under 13. Age verification on signup |
| 10.3 | GDPR compliance | EU students supported via separate addendum (DPA + SCC) |
| 10.4 | CCPA / CPRA | Privacy Policy disclosures; data export/deletion rights honored |
| 10.5 | Data Processing Addendum | Available; signed pre-contract |

---

## 11. Accessibility

| # | 質問 | 回答 |
|---|------|------|
| 11.1 | Section 508 conformance | VPAT 2.5 self-assessment available on request |
| 11.2 | WCAG 2.1 AA conformance | Targeted in design; ongoing testing with VoiceOver and Dynamic Type |
| 11.3 | Accessibility testing process | Manual testing with iOS VoiceOver; planned third-party audit 2026-Q3 |

---

## 12. Business Continuity

| # | 質問 | 回答 |
|---|------|------|
| 12.1 | RTO (Recovery Time Objective) | 4 hours for service restoration |
| 12.2 | RPO (Recovery Point Objective) | 24 hours (daily backup); 5 minutes for PITR-eligible data |
| 12.3 | Single-founder dependency mitigation | Documented runbooks; planned co-founder/contractor onboarding 2026-Q4 |

---

## 13. Vendor Risk Management

| # | 質問 | 回答 |
|---|------|------|
| 13.1 | Subprocessor due diligence | Deepgram (SOC 2 Type II), Supabase (SOC 2 Type II), Stripe (PCI Level 1, SOC 2). Annual review |
| 13.2 | Subprocessor agreements | DPA in place with each |

---

## 14. Compliance & Certifications

| # | 質問 | 回答 |
|---|------|------|
| 14.1 | SOC 2 Type II | In preparation, target 2027-Q1 |
| 14.2 | ISO 27001 | Not at this time |
| 14.3 | HITRUST | Not at this time |
| 14.4 | FedRAMP | Not at this time |
| 14.5 | StateRAMP | Not at this time |

---

## 15. Contractual

| # | 質問 | 回答 |
|---|------|------|
| 15.1 | DPA signing | Yes, available for review and signature |
| 15.2 | BAA (HIPAA) | N/A — service not designed for PHI |
| 15.3 | FERPA Addendum | Yes, available |
| 15.4 | Insurance certificate | $1M Cyber Liability + E&O planned pre-first-paid-contract |
| 15.5 | Contract term | Annual or monthly |
| 15.6 | Auto-renewal | Yes, with 30-day cancellation notice |

---

## 営業時の使い方TIPS

1. **「準備中」の項目は隠さず正直に書く** — 大学IT審査員はベンダーの段階を理解する。隠すと信用失う
2. **N/A は必ず理由を添える** — 「Not applicable: audio is not stored」と1行
3. **回答できない項目は「Will provide post-pilot」と書く** — 即答できない=営業終了 ではない
4. **質問が来てから2週間以内に返す** — それ以降は他社に取られる
5. **Lite版で済むケースが多い** — Full版（300問+）が必要な大学のみ追加対応

---

## 改訂履歴

- 2026-04-14: 初版作成（Deepgram移行と整合）

---

*関連: [_営業プレイブック共通](./_営業プレイブック共通.md) / [Deepgram-only設計_2026](../lecsy/技術/Deepgram-only設計_2026.md)*

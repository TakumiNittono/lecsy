# Lecsy Security Overview

**Version:** 1.0
**Last updated:** 2026-04-06

This document is a one-page summary of Lecsy's security posture for prospective customers and security teams.

## Architecture Highlights

- **On-device transcription:** Voice recordings are processed entirely on the user's iPhone using Apple's WhisperKit. Audio files never leave the device unless the user explicitly opts in.
- **End-to-end encryption:** TLS 1.2+ for all data in transit; AES-256 at rest for all data stored in our database and storage layer.
- **Zero-trust authorization:** Every API call enforces role-based access control at both the application layer and the database layer (Postgres Row Level Security).

## Data Flow

```
[iPhone] ── recording ──→ [WhisperKit on-device] ── text ──→ [Supabase Postgres (US-East)]
                                                                     │
                                                                     ├──→ [OpenAI API (text only, opt-in)]
                                                                     ├──→ [Stripe (billing metadata only)]
                                                                     └──→ [Sentry (PII-scrubbed errors)]
```

## Authentication & Authorization

- Apple / Google OAuth (B2C and B2B individual users)
- SAML 2.0 SSO (Business and Enterprise plans)
- SCIM 2.0 user provisioning (Enterprise plans)
- Multi-factor authentication available; required for administrators on Business plans and above
- Role-based access control: owner / admin / teacher / student

## Data Protection

- **Encryption at rest:** AES-256 (Supabase managed)
- **Encryption in transit:** TLS 1.2+ everywhere; HSTS preloaded
- **Backups:** Daily encrypted backups with point-in-time recovery
- **Retention:** Configurable per organization; default: indefinite for active organizations, 30 days post-termination
- **Deletion:** Hard delete on request; GDPR Article 17 compliant; 30-day SLA

## Application Security

- All third-party dependencies monitored for vulnerabilities (Dependabot)
- Static analysis (Semgrep) on every pull request
- Annual third-party penetration testing
- Bug bounty program (planned for Phase 2)
- All code changes reviewed before merge

## Operational Security

- Production access restricted to authorized personnel with MFA
- Quarterly access reviews
- Centralized logging with 1-year retention
- 24/7 monitoring and alerting (PagerDuty)
- Incident response runbook with 72-hour breach notification commitment

## Compliance & Certifications

| Framework | Status |
|---|---|
| GDPR | Compliant; DPA available on request |
| FERPA | Compliant for educational use; addendum available |
| CCPA | Compliant |
| SOC 2 Type I | In progress (target: Q3 2026) |
| SOC 2 Type II | Planned (target: Q1 2027) |
| ISO 27001 | Roadmap (Phase 3) |
| HIPAA | BAA available for qualifying customers |

## Subprocessors

See [`SUBPROCESSORS.md`](./SUBPROCESSORS.md). All subprocessors are SOC 2 certified or equivalent.

## Incident Response

- 72-hour breach notification commitment
- Status page: `status.lecsy.app`
- Public RCA within 5 business days for all Severity 1 and 2 incidents

## Contact

- Security questions: `security@lecsy.app`
- Vulnerability disclosure: `security@lecsy.app` (PGP key available)
- Privacy / DSAR requests: `privacy@lecsy.app`

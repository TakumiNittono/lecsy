# Lecsy SOC 2 Roadmap

**Last updated:** 2026-04-06

## Goal

Achieve SOC 2 Type I attestation by Q3 2026, followed by SOC 2 Type II attestation by Q1 2027.

## Approach

Lecsy will use a compliance automation platform (Vanta or Drata) to monitor controls continuously, gather evidence automatically, and prepare audit-ready artifacts.

## Trust Service Criteria in Scope

For Type I and Type II:
- **Security** (mandatory)
- **Availability**
- **Confidentiality**

The Privacy and Processing Integrity criteria will be added in a future audit cycle if customer demand requires.

## Phase 1 — Readiness (Months 1–2)

- [ ] Engage compliance automation vendor (Vanta or Drata)
- [ ] Engage independent SOC 2 auditor
- [ ] Document information security policies (Acceptable Use, Access Control, Change Management, Incident Response, Vendor Management, Data Classification, Business Continuity, Cryptography)
- [ ] Identify control owners
- [ ] Define scope (production environment, employees, contractors)
- [ ] Conduct readiness assessment

## Phase 2 — Implementation (Months 3–4)

- [ ] Deploy MFA for all production access
- [ ] Implement centralized identity provider for internal users
- [ ] Enable detailed audit logging across all production systems
- [ ] Implement vulnerability management (weekly scans, monthly patching cadence)
- [ ] Implement backup and disaster recovery testing (quarterly)
- [ ] Document and test incident response procedures
- [ ] Implement vendor security review process
- [ ] Implement employee onboarding/offboarding checklists
- [ ] Implement annual security awareness training

## Phase 3 — Type I Audit (Month 5)

- [ ] Run point-in-time control testing
- [ ] Address any gaps identified
- [ ] Receive SOC 2 Type I attestation report

## Phase 4 — Type II Observation Period (Months 6–11)

- [ ] Maintain controls continuously for 6 months
- [ ] Quarterly internal control reviews
- [ ] Address any deficiencies promptly

## Phase 5 — Type II Audit (Month 12)

- [ ] Provide auditor with evidence covering the observation period
- [ ] Receive SOC 2 Type II attestation report
- [ ] Publish to customer trust portal (under NDA)

## Ongoing

- Annual recertification
- Continuous monitoring via compliance platform
- Quarterly access reviews
- Annual penetration testing
- Annual policy review and update

## Compliance Adjacencies

After SOC 2 Type II, the following are on the roadmap:
- ISO 27001 (Phase 3)
- HIPAA BAA capability formalization
- FedRAMP Moderate (only if pursuing federal customers)
- StateRAMP (for state-level education customers)

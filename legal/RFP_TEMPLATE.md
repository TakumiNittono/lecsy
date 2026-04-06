# Lecsy RFP Response Template

**Version:** 1.0
**Use:** Pre-filled answers to the 30 most common RFP/security questionnaire questions from educational and enterprise prospects.

---

## Section 1: Company & Product

**Q1. Company name, headquarters, year founded, number of employees.**
A. Lecsy. Founded 2025. Headquarters: [TBD]. Currently a small focused team led by the founder; engineering scaling per Phase 2 plan.

**Q2. Briefly describe the product.**
A. Lecsy is an iOS-first speech-to-text and AI summarization platform for language learning, with B2B organization management for schools, universities, and enterprises. Recordings are processed on-device using Apple's WhisperKit.

**Q3. Who are your typical customers?**
A. Language schools, university Intensive English Programs (IEPs), college language departments, and corporate L&D teams.

**Q4. Where is your product hosted?**
A. Supabase (US-East by default). EU and Asia-Pacific regions available for Enterprise customers.

---

## Section 2: Data & Privacy

**Q5. Where is customer data stored?**
A. US-East (Virginia) by default. Enterprise customers can elect EU-West (Ireland) or Asia-Pacific (Tokyo).

**Q6. Is data encrypted in transit and at rest?**
A. Yes. TLS 1.2+ in transit; AES-256 at rest. Voice recordings are processed on-device and never leave the device unless explicitly opted in.

**Q7. Do you process special category data (e.g., health, biometrics, minors)?**
A. We do not intentionally process special category data. Customers using Lecsy with minors must obtain appropriate consents (FERPA, COPPA where applicable). Voice recordings are not used as biometric identifiers.

**Q8. How long is data retained?**
A. Configurable per organization. Default: indefinite for active orgs; 30 days post-termination. Customers can set 90 days, 1 year, 3 years, or indefinite.

**Q9. How do you handle data deletion requests (GDPR Article 17 / CCPA)?**
A. Hard delete within 30 days of request. Process available via in-app, email, or Web admin console.

**Q10. Do you sign a Data Processing Agreement (DPA)?**
A. Yes. GDPR-compliant DPA available, including Standard Contractual Clauses (Module Two) for international transfers.

**Q11. Do you transfer data outside the EU?**
A. Yes, to the US, governed by SCC 2021 + supplementary measures. EU data residency available on Enterprise.

**Q12. Are you FERPA compliant?**
A. Yes. We follow FERPA-aligned data handling practices and provide a FERPA addendum for educational customers.

**Q13. Are you HIPAA compliant?**
A. We can sign a Business Associate Agreement for qualifying customers. Lecsy is not generally intended for protected health information.

---

## Section 3: Security

**Q14. Do you have SOC 2 / ISO 27001 / other certifications?**
A. SOC 2 Type I in progress (target Q3 2026), Type II planned for Q1 2027. ISO 27001 on roadmap (Phase 3).

**Q15. Have you had an independent security assessment?**
A. Annual third-party penetration test starting Phase 1.5. Continuous static analysis and dependency scanning.

**Q16. How are passwords stored?**
A. We do not store passwords directly. Authentication is delegated to Supabase Auth (which stores bcrypt-hashed passwords) or to identity providers via OAuth/SAML.

**Q17. Do you support Single Sign-On (SSO)?**
A. SAML 2.0 SSO is available on Business and Enterprise plans. Compatible with Okta, Azure AD/Entra ID, Google Workspace, OneLogin, Shibboleth.

**Q18. Do you support SCIM provisioning?**
A. SCIM 2.0 available on Enterprise plans.

**Q19. Do you support multi-factor authentication?**
A. Yes. TOTP standard. WebAuthn/Passkey on roadmap. Required for administrators on Business+ plans.

**Q20. Describe your access control model.**
A. Role-based: owner / admin / teacher / student. Enforced at application layer and database layer (Postgres Row Level Security). Quarterly access reviews internally.

**Q21. How do you handle vulnerability management?**
A. Continuous dependency scanning (Dependabot), weekly vulnerability scans, monthly patching cadence. Critical vulnerabilities patched within 24 hours.

**Q22. What is your incident response process?**
A. Documented runbook. 72-hour breach notification. Status page at status.lecsy.app. RCA published within 5 business days for Severity 1/2 incidents.

---

## Section 4: Availability & Reliability

**Q23. What is your uptime SLA?**
A. 99.9% (Business), 99.95% (Enterprise). Service credits available.

**Q24. What is your disaster recovery plan?**
A. Daily encrypted backups with point-in-time recovery (7–30 days depending on plan). RTO 4h / RPO 1h for Business; RTO 2h / RPO 30min for Enterprise. Tested quarterly.

**Q25. Do you have a status page?**
A. Yes. `status.lecsy.app` (Statuspage.io).

---

## Section 5: Subprocessors & Third Parties

**Q26. Provide a list of subprocessors.**
A. See `SUBPROCESSORS.md`. Primary subprocessors: Supabase (DB/Auth), OpenAI (AI), Stripe (billing), Cloudflare (CDN/WAF), Sentry (monitoring), Resend (email).

**Q27. How are subprocessors vetted?**
A. SOC 2 / ISO 27001 certification required. Annual review. Security questionnaire on onboarding. DPA in place.

---

## Section 6: Operations

**Q28. How do you handle employee security?**
A. Background checks, MFA-enforced production access, principle of least privilege, annual security training, confidentiality agreements.

**Q29. Do you have cyber insurance?**
A. Yes (in progress for Phase 1.5). Coverage: $1M minimum, increasing to $5M before Enterprise contracts.

**Q30. What happens to our data if Lecsy goes out of business?**
A. Customers can export all data at any time via the Web admin console. In a wind-down, we commit to providing 90 days of read-only access for export. Source code escrow available for Enterprise customers on request.

---

## Contact for Detailed Questions

- Security: `security@lecsy.app`
- Privacy: `privacy@lecsy.app`
- Legal: `legal@lecsy.app`
- Sales: `sales@lecsy.app`

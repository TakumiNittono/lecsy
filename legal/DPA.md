# Data Processing Agreement (DPA)

**Version:** 1.0 (TEMPLATE — pending counsel review)
**Effective Date:** _______________

This Data Processing Agreement ("DPA") forms part of the Master Services Agreement between **Lecsy** ("Processor") and **[Customer Legal Name]** ("Controller"). It applies where Processor processes Personal Data on behalf of Controller in the course of providing the Services.

This DPA reflects the parties' agreement on the processing of Personal Data subject to the EU General Data Protection Regulation (GDPR), the UK GDPR, and other applicable data protection laws.

## 1. Definitions

Terms not defined here have the meaning given in the GDPR. "Personal Data," "Data Subject," "Processing," "Controller," "Processor," "Subprocessor," and "Supervisory Authority" have the meanings given in Article 4 GDPR.

## 2. Roles and Subject Matter

2.1 Controller is the controller and Processor is the processor of Personal Data.

2.2 **Subject matter:** provision of the Lecsy Services.

2.3 **Duration:** the term of the underlying agreement.

2.4 **Nature and purpose of processing:** providing speech-to-text transcription, AI summarization, classroom collaboration, and organization administration features.

2.5 **Categories of Data Subjects:** Controller's authorized users (administrators, teachers, students).

2.6 **Categories of Personal Data:**
- Identification: name, email
- Authentication: hashed passwords, OAuth tokens
- Content: voice recording transcripts, AI-generated summaries
- Usage: log data, IP addresses, device identifiers

2.7 **Special categories of data:** Lecsy does not intentionally process special category data. Controller must obtain appropriate consents if recordings include such data.

## 3. Processor Obligations

Processor shall:
- Process Personal Data only on Controller's documented instructions
- Ensure persons authorized to process Personal Data are bound by confidentiality
- Implement appropriate technical and organizational measures (Annex II)
- Assist Controller in responding to Data Subject requests
- Assist Controller in complying with Articles 32–36 GDPR
- Delete or return Personal Data at the end of the Services
- Make available all information necessary to demonstrate compliance

## 4. Subprocessors

4.1 Controller authorizes Processor to engage the Subprocessors listed in Annex III and `SUBPROCESSORS.md`.

4.2 Processor will notify Controller of any new Subprocessor at least 30 days before authorization. Controller may object on reasonable grounds; if the parties cannot agree, Controller may terminate the affected Services.

4.3 Processor remains liable for Subprocessor compliance.

## 5. Data Subject Rights

Processor shall, taking into account the nature of processing, assist Controller by appropriate technical and organizational measures, in fulfilling Controller's obligation to respond to Data Subject requests under GDPR Articles 12–22.

## 6. Personal Data Breach

6.1 Processor shall notify Controller of any Personal Data Breach without undue delay and in any case within 72 hours of becoming aware.

6.2 The notification will include, to the extent known: nature of the breach, categories and approximate number of data subjects, likely consequences, and measures taken or proposed.

## 7. Data Protection Impact Assessments

Processor will provide Controller with reasonable assistance for any data protection impact assessment and prior consultations with Supervisory Authorities.

## 8. International Transfers

8.1 Personal Data may be transferred outside the EEA / UK to the United States, where Processor and certain Subprocessors are located.

8.2 Such transfers are governed by the Standard Contractual Clauses (Module Two: Controller to Processor) approved by the European Commission Implementing Decision (EU) 2021/914, incorporated by reference. Where required, the UK International Data Transfer Addendum applies.

8.3 Annex IV sets out the technical, contractual, and organizational supplementary measures.

## 9. Audits

9.1 Processor will make available to Controller all information necessary to demonstrate compliance with this DPA and allow audits, including inspections, conducted by Controller or an auditor mandated by Controller.

9.2 Such audits may take place no more than once per year, with at least 30 days' prior notice, during normal business hours, and shall not unreasonably interfere with Processor's operations.

9.3 Audits may be satisfied by providing Controller with Processor's most recent SOC 2 Type II report or equivalent.

## 10. Deletion or Return of Personal Data

10.1 Upon termination of the underlying agreement, Processor will, at Controller's choice, delete or return all Personal Data within 30 days.

10.2 Controller may extend retention by written request for legal compliance purposes.

10.3 Processor may retain Personal Data to the extent required by applicable law.

## 11. Liability

The liability of each party under this DPA is governed by the limitations set out in the underlying agreement.

---

## Annex I — Description of Processing

(See sections 2.4–2.6 above)

## Annex II — Technical and Organizational Measures

- **Encryption:** TLS 1.2+ in transit; AES-256 at rest
- **Access controls:** role-based access, MFA for all administrative access, principle of least privilege
- **Network security:** WAF, DDoS protection, intrusion detection
- **Application security:** SAST, dependency scanning, annual penetration testing
- **Logging and monitoring:** centralized logging with 1-year retention, 24/7 alerting
- **Backups:** daily encrypted backups with point-in-time recovery
- **Incident response:** documented procedures, 72-hour breach notification
- **Personnel security:** background checks, confidentiality agreements, annual security training
- **Physical security:** subprocessor data centers with SOC 2 / ISO 27001 certification
- **Business continuity:** documented disaster recovery plan with RTO 4h / RPO 1h

## Annex III — Authorized Subprocessors

See `SUBPROCESSORS.md` for the current list. Updates will be communicated as set out in Section 4.

## Annex IV — Supplementary Measures for International Transfers

- Encryption in transit and at rest as described in Annex II
- No bulk access by foreign authorities; Processor will challenge any unlawful access requests
- Transparency reports published annually
- Strong contractual obligations on Subprocessors mirroring this DPA

---

**PROCESSOR:**
Lecsy
By: _________________________

**CONTROLLER:**
[Customer Legal Name]
By: _________________________

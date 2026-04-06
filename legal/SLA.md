# Service Level Agreement (SLA)

**Version:** 1.0
**Effective Date:** _______________

This SLA forms part of the Master Services Agreement between Lecsy ("Provider") and Customer.

## 1. Service Availability Commitment

| Plan | Monthly Uptime Commitment | Allowed Monthly Downtime |
|---|---|---|
| Starter | Best effort (no commitment) | n/a |
| Growth | 99.5% | ~3h 39min |
| Business | 99.9% | ~43min |
| Enterprise | 99.95% | ~21min |

### Definitions

- **"Monthly Uptime Percentage"** is calculated as: `(Total Minutes in Month - Downtime Minutes) / Total Minutes in Month × 100`.
- **"Downtime"** means any period during which the Services are unavailable to Customer's authorized users, as confirmed by Provider's monitoring and the public status page at `status.lecsy.app`.
- **Excluded from Downtime:**
  - Scheduled maintenance announced at least 48 hours in advance (Provider will limit scheduled maintenance to off-peak hours and will not exceed 4 hours per month)
  - Force majeure events
  - Customer-caused issues (misconfiguration, exceeded rate limits, network issues on Customer's side)
  - Failures of third-party services explicitly outside Provider's control (e.g., Apple App Store, customer SSO IdP)
  - Periods during which the iOS app continues to function (recording, on-device transcription) even when cloud sync is degraded

## 2. Service Credits

If Provider fails to meet the Monthly Uptime Commitment in a calendar month, Customer is entitled to the following service credits, applied to the next monthly invoice:

| Monthly Uptime | Service Credit |
|---|---|
| < 99.9% but ≥ 99.0% | 10% of monthly fee |
| < 99.0% but ≥ 95.0% | 25% of monthly fee |
| < 95.0% | 50% of monthly fee |

### Credit Request Process

To receive a service credit, Customer must submit a written request to `support@lecsy.app` within 30 days of the end of the month in which the SLA breach occurred. The request must include:
- Dates and times of each Downtime incident
- Affected users or organizations
- Description of impact

Service credits are Customer's sole and exclusive remedy for SLA breaches.

## 3. Support Response Times

| Plan | Channel | Severity 1 (system down) | Severity 2 (major impact) | Severity 3 (minor) |
|---|---|---|---|---|
| Starter | Email | 48 hours | 72 hours | 5 business days |
| Growth | Email | 24 hours | 48 hours | 3 business days |
| Business | Email + Slack | 8 hours | 24 hours | 2 business days |
| Enterprise | Email + Slack + Phone | 1 hour | 4 hours | 1 business day |

### Severity Definitions

- **Severity 1:** Service is completely unavailable for the majority of users
- **Severity 2:** Major functionality is unavailable or severely degraded
- **Severity 3:** Minor issue with workaround available

## 4. Incident Communication

For Severity 1 and 2 incidents, Provider will:
1. Acknowledge within the response time specified above
2. Post initial status update on `status.lecsy.app` within 15 minutes
3. Provide hourly updates until resolution
4. Publish a Root Cause Analysis (RCA) within 5 business days of resolution

## 5. Maintenance

5.1 **Scheduled maintenance** will be announced at least 48 hours in advance via the status page and email to organization owners.

5.2 **Emergency maintenance** may be performed without advance notice when necessary to address security vulnerabilities or critical issues.

## 6. Performance Targets (informational, not credit-bearing)

| Metric | Business | Enterprise |
|---|---|---|
| API p95 latency | < 500ms | < 300ms |
| Recording save success rate | 99.95% | 99.99% |
| AI summary success rate | 99% | 99.5% |
| Mean Time To Recovery (MTTR) | 4h | 2h |

## 7. Disaster Recovery

| Plan | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) | Backup Retention |
|---|---|---|---|
| Growth | 24 hours | 4 hours | 7 days |
| Business | 4 hours | 1 hour | 30 days |
| Enterprise | 2 hours | 30 minutes | 90 days |

## 8. Modifications

Provider may modify this SLA from time to time, provided that no modification will materially reduce Provider's obligations during the then-current Subscription Term.

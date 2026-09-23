# Security Policy

The security of `secure_token_manager` and the credentials entrusted to it is paramount. We take all potential security vulnerabilities seriously.

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

---

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities via public GitHub issues, discussions, or pull requests.**

If you discover or suspect a security vulnerability in this package:

1. **Email us privately** at: `amritmaurya41@gmail.com` (or submit a Private Vulnerability Advisory on GitHub if enabled).
2. Include the following details:
   - A description of the vulnerability and its potential impact.
   - Step-by-step instructions or proof-of-concept code to reproduce the issue.
   - Affected platforms (Android, iOS, macOS, Windows, Linux).
   - Any proposed remediation or patch, if available.

---

## Response Process

- We will acknowledge receipt of your vulnerability report within 48 hours.
- We will coordinate with you to validate the findings and determine the severity.
- Once fixed, a security release will be published on pub.dev, and credit will be given to the reporter (unless anonymity is requested).
- We ask for responsible disclosure: please allow us reasonable time to release a patch before disclosing details publicly.

---

## Core Security Guarantees & Assumptions

- **Secrets Redaction**: `secure_token_manager` ensures tokens are never printed in `toString()`, error strings, or logs.
- **Hardware-Backed Isolation**: Platform stores utilize the OS credential vault.
- **Managed Memory Note**: Dart VM strings reside in garbage-collected memory and cannot be wiped on demand. Applications requiring zero memory exposure must minimize token longevity and utilize short-lived access tokens.


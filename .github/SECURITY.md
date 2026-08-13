# Security Policy

## Supported Versions

Security updates are provided for the **latest release only**. We do not patch
older versions — always update to the newest release before reporting or relying
on a fix.

## Reporting a Vulnerability

Please **do not** open a public issue for security vulnerabilities.

Report vulnerabilities privately via the **GitHub Security Advisories** flow:

1. Open the **Security** tab on the repository
   (https://github.com/karan5028ji/Win-Optimizer-Pro/security).
2. Click **Report a vulnerability** and fill in the details.

You can also email the maintainer directly at **karan5028ji@gmail.com**.
Encrypted / detailed reports are appreciated but not required.

### What to include

- Affected version (release tag or commit hash)
- Steps to reproduce
- Expected vs. actual behavior
- Impact description (what an attacker could do)
- Any suggested fix, if you have one

### What happens next

- We aim to acknowledge reports within **48 hours**.
- We will coordinate on a fix and a release, and credit you in the advisory
  unless you prefer to remain anonymous.
- We ask that you keep the report private until a fix is released.

## Scope

The project runs PowerShell scripts that perform real system modifications
(app removal, registry edits, file deletion). Malicious or injected PowerShell
input is treated as a high-severity issue.

Out of scope: issues in third-party dependencies that are already reported
upstream, and general security advice.

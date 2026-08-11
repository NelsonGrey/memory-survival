# Security Policy

## Supported Versions

**Memory-Allocation Survival** is currently in discovery / pre-release status — see [Business Requirements](./docs/BUSINESS_REQUIREMENTS.md). There is a single active line of development (`main`); no long-term-support branches exist yet.

| Environment | GCP project        | Status                        |
| ----------- | ------------------- | ------------------------------ |
| Development | `memory-alloc-survival-dev`     | Active                          |
| Staging     | `memory-alloc-survival-staging` | Active                          |
| Production  | `memory-alloc-survival-prod`    | Provisioned, not yet released   |

## Reporting a Vulnerability

This is a private repository, so please do not open a public issue for a security concern.

Instead, email **admin@nelsongrey.com** with:

- A description of the vulnerability and its potential impact
- Steps to reproduce, or a proof of concept if available
- Any relevant logs, request/response samples, or affected endpoints

You should get an acknowledgement within a few business days. This is a small, pre-release project without a formal bug bounty program, but genuine reports are taken seriously and fixed promptly.

## Automated Dependency Scanning

Dependabot alerts are enabled on this repository (org default), and `.github/dependabot.yml` opens weekly update PRs for GitHub Actions, the Cloud Functions npm dependencies, and the Flutter/pub dependencies. Native GitHub secret scanning and code scanning (CodeQL) require GitHub Advanced Security, which isn't currently licensed for this org's private repositories, so neither is enabled here. Avoid committing credentials or secrets to this repo regardless — downloaded Firebase config (`firebase-config/`) is gitignored, and there are no other runtime secrets checked in.

# Security Policy

## Supported Versions

**Memory Survival** is currently in discovery / pre-release status — see [Business Requirements](./docs/BUSINESS_REQUIREMENTS.md). Development flows `develop` → `staging` → `main`; only the code on these three branches is supported, there is no long-term support for older commits. There is no backend project (Game Center/Play Games Services hold all account state — see the README), so there's no separate per-environment infrastructure to track here.

| Branch | Environment | Status |
|---|---|---|
| `main` | Production | Supported |
| `staging` | Staging | Supported |
| `develop` | Development | Supported |

## Reporting a Vulnerability

This repository doesn't have a public issue tracker, so please don't report security concerns that way. Use one of:

- GitHub's [private vulnerability reporting](https://github.com/NelsonGrey/memory-survival/security/advisories/new), or
- Email **support@nelsongrey.com**

Either way, include:

- A description of the vulnerability and its potential impact
- Steps to reproduce, or a proof of concept if available
- Any relevant logs, request/response samples, or affected endpoints

You should get an acknowledgement within a few business days.

## Automated Dependency Scanning

Dependabot alerts are enabled on this repository, and `.github/dependabot.yml` opens update PRs for GitHub Actions and the Flutter/pub dependencies. Native GitHub secret scanning and code scanning (CodeQL) require GitHub Advanced Security, which isn't currently licensed for this org's private repositories, so neither is enabled here. Avoid committing credentials or secrets regardless — CI and release secrets live in GitHub Actions secrets, never in source.

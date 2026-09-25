# Security Policy

## Supported Versions

This repository holds Memory-Allocation Survival, a Flutter + Firebase mobile puzzle-game client and Cloud Functions backend built on the Modulo Squares portfolio architecture. Only the code currently deployed on each environment branch is supported — there is no long-term support for older commits.

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

Dependabot alerts are enabled on this repository, and `.github/dependabot.yml` opens update PRs for GitHub Actions, the Cloud Functions npm dependencies, and the Flutter/pub dependencies. Native GitHub secret scanning and code scanning (CodeQL) require GitHub Advanced Security, which isn't currently licensed for this org's private repositories, so neither is enabled here. Avoid committing credentials or secrets regardless — runtime secrets are managed via Firebase Secret Manager / GitHub Actions secrets, never committed to source, and downloaded per-environment Firebase config (`firebase-config/`) is gitignored.

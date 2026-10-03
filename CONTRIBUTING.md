# Contributing

Memory Survival is a private, closed-source project in discovery / pre-release status. It isn't open to outside contributions — there's no public issue tracker or pull request process for external contributors.

If you have collaborator access to this repository:

1. Branch from `develop` (`feature/<short-description>` or `fix/<short-description>`) — `develop` is the active integration branch; `staging` and `main` are only updated via promotion PRs.
2. Keep commits focused, and write commit messages that explain *why*, not just *what*.
3. Before opening a pull request, run the checks for whatever you touched: `flutter analyze` and `flutter test` in `packages/mobile`.
4. Open the PR against `develop` and request review — don't merge your own changes without one.

Questions about contributing should go to the repository owner (see SUPPORT.md).

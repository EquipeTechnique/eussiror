# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-02-26

### Fixed
- Gem version badge: use shields.io instead of badge.fury.io (fixes "not found").

## [0.2.1] - 2026-02-26

### Added
- Step-by-step GitHub token setup guide in README (beginner-friendly).

## [0.2.0] - 2026-02-26

### Changed
- Drop Ruby 3.1 support; minimum Ruby is now 3.2.0 (fixes Psych/strscan compatibility issues).
- Disable Rails/NegateInclude RuboCop rule.

## [0.1.0] - 2026-02-26

### Added
- Initial release.
- Rack middleware that detects 500 responses and reads `env["action_dispatch.exception"]`.
- SHA256-based fingerprinting to deduplicate errors across occurrences.
- GitHub REST API v3 client (zero runtime dependencies, uses `Net::HTTP`).
- Automatic issue creation on first occurrence of a given error.
- Automatic comment on existing open issue for repeat occurrences.
- `Eussiror.configure` block with support for token, repository, environments, labels, assignees, ignored exceptions, and async mode.
- Rails install generator (`rails generate eussiror:install`).
- RuboCop configuration.
- GitHub Actions CI matrix: Ruby 3.1–3.4 × Rails 7.2–8.1.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Breaking:** Replace Rack middleware with `Rails.error.subscribe` (`ActiveSupport::ErrorReporter`). Eussiror now catches **all** unhandled exceptions (HTTP requests, ActiveJob, Action Cable, Rake, etc.), not just HTTP 500s.
- Issue titles use source-aware tags (`[request]`, `[job]`, `[cable]`, `[error]`) instead of `[500]`.
- `Eussiror::Middleware` has been removed; `Eussiror::ErrorSubscriber` replaces it.
- Source classification is now hybrid (strict mapping + heuristics on source strings) to reduce false `[error]` tags across Rails/runtime variants.

### Added
- `Eussiror::ErrorSubscriber` — `Rails.error` subscriber registered via the Railtie.
- `Configuration#report_handled_errors` (default `false`) to optionally report errors caught by `Rails.error.handle`.
- **Source** line in issue Context section for non-default sources (e.g. `job`, `request`).
- Additional release environment variables (`SOURCE_VERSION`, `RAILWAY_GIT_COMMIT_SHA`, `RENDER_GIT_COMMIT`, `CI_COMMIT_SHA`, `GITHUB_SHA`) alongside existing keys.
- `Eussiror::ContextExtractor` to normalize heterogeneous Rails.error context payloads (string/symbol keys, nested env/request/headers, request objects).

## [0.3.0] - 2026-04-02

### Added
- `Configuration#issue_privacy` (`:minimal`, `:standard`, `:full`) and `Configuration#environment_name`.
- `Eussiror::IssueFormatting` for structured GitHub issue bodies and repeat-occurrence comments.
- Post-install notice after `rails generate eussiror:install`.

### Changed
- Issue and comment content use the new formatting; optional release from `RELEASE`, `HEROKU_SLUG_COMMIT`, `REVISION`, or `GIT_COMMIT`.

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

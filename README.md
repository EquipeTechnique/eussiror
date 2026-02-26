# Eussiror

**Maintainer:** [@tracyloisel](https://github.com/tracyloisel)

[![Gem Version](https://badge.fury.io/rb/eussiror.svg)](https://badge.fury.io/rb/eussiror)
[![CI](https://github.com/EquipeTechnique/eussiror/actions/workflows/ci.yml/badge.svg)](https://github.com/EquipeTechnique/eussiror/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Eussiror** automatically creates GitHub issues when your Rails application returns a 500 error in production. If the same error already has an open issue, it adds a comment with the new occurrence timestamp instead — keeping your issue tracker clean and deduplicated.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [How it works](#how-it-works)
- [GitHub token setup](#github-token-setup)
- [Architecture (for contributors)](#architecture-for-contributors)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Requirements

| Dependency | Minimum version |
|---|---|
| Ruby | 3.1 |
| Rails | 7.2 |

> **Note:** No additional runtime gems are required. Eussiror uses Ruby's built-in `Net::HTTP` to call the GitHub API.

---

## Installation

Add the gem to your application's `Gemfile`:

```ruby
gem "eussiror"
```

Then run:

```bash
bundle install
rails generate eussiror:install
```

The generator creates `config/initializers/eussiror.rb` with all available options commented out. To undo the installation:

```bash
rails destroy eussiror:install
```

---

## Configuration

Edit the generated initializer:

```ruby
# config/initializers/eussiror.rb
Eussiror.configure do |config|
  # Required: GitHub personal access token with "repo" scope
  config.github_token = ENV["GITHUB_TOKEN"]

  # Required: target repository in "owner/repository" format
  config.github_repository = "your-org/your-repo"

  # Environments where 500 errors will be reported (default: ["production"])
  config.environments = %w[production]

  # Labels applied to every new issue (optional)
  config.labels = %w[bug automated]

  # GitHub logins to assign to new issues (optional)
  config.assignees = []

  # Exception classes that should NOT trigger issue creation (optional)
  config.ignored_exceptions = %w[ActionController::RoutingError]

  # Set to false to report synchronously — recommended in test environments
  config.async = false
end
```

### Configuration options

| Option | Type | Default | Description |
|---|---|---|---|
| `github_token` | String | `nil` | GitHub token with `repo` (or Issues write) permission |
| `github_repository` | String | `nil` | Target repo in `owner/repo` format |
| `environments` | Array | `["production"]` | Environments where reporting is active |
| `labels` | Array | `[]` | Labels applied to created issues |
| `assignees` | Array | `[]` | GitHub logins assigned to created issues |
| `ignored_exceptions` | Array | `[]` | Exception class names (strings) to skip |
| `async` | Boolean | `true` | Report in a background thread (set `false` in tests) |

---

## How it works

When a 500 error occurs:

1. The Rack middleware catches the rendered 500 response.
2. A **fingerprint** is computed from the exception class, message, and first application backtrace line.
3. The GitHub API is searched for an open issue containing that fingerprint.
4. If **no issue exists** → a new issue is created with the exception details.
5. If **an issue exists** → a comment with the current timestamp is added.

### Example GitHub issue

**Title:** `[500] RuntimeError: something went wrong`

**Body:**
```
## Error Details

**Exception:** `RuntimeError`
**Message:** something went wrong
**First occurrence:** 2026-02-26 10:30:00 UTC
**Request:** `GET /dashboard`
**Remote IP:** 1.2.3.4

## Backtrace

app/controllers/dashboard_controller.rb:42:in 'index'
...
```

### Example occurrence comment

```
**New occurrence:** 2026-02-26 14:55:02 UTC
```

---

## GitHub token setup

Eussiror needs a GitHub token with permission to read and create issues on your target repository.

**Option A — Classic personal access token:**
Generate at `Settings → Developer settings → Personal access tokens → Tokens (classic)` and select the `repo` scope.

**Option B — Fine-grained personal access token:**
Generate at `Settings → Developer settings → Personal access tokens → Fine-grained tokens`. Grant **Issues → Read and write** on the target repository only.

Store the token in an environment variable (never hard-code it):

```bash
# .env or your secrets manager
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

---

## Architecture (for contributors)

This section describes the internal design of Eussiror to help contributors understand where everything lives and how the pieces connect.

### File map

```
lib/
├── eussiror.rb                         # Public API: .configure / .configuration / .reset_configuration!
└── eussiror/
    ├── version.rb                      # Gem version constant
    ├── configuration.rb                # Configuration value object + guards
    ├── railtie.rb                      # Rails integration: inserts Middleware into the stack
    ├── middleware.rb                   # Rack middleware: detects 500s and calls ErrorReporter
    ├── fingerprint.rb                  # Computes a stable SHA256 fingerprint per exception type
    ├── github_client.rb                # GitHub REST API v3 calls via Net::HTTP
    └── error_reporter.rb               # Orchestrator: fingerprint → search → create or comment

lib/generators/eussiror/install/
├── install_generator.rb                # `rails generate eussiror:install`
└── templates/initializer.rb.tt         # Template for config/initializers/eussiror.rb
```

### Request / error flow

```
HTTP Request
    │
    ▼
Eussiror::Middleware          (outermost Rack middleware)
    │
    ▼
ActionDispatch::ShowExceptions (catches Rails exceptions, stores them in env)
    │
    ▼
[... rest of Rails stack ...]
    │
    ▼  (response travels back up)
ActionDispatch::ShowExceptions → sets env["action_dispatch.exception"]
                                 returns HTTP 500 response
    │
    ▼
Eussiror::Middleware
    ├── status == 500 AND env["action_dispatch.exception"] present?
    │     YES → ErrorReporter.report(exception, env)
    │     NO  → pass response through unchanged
    │
    ▼
HTTP Response returned to client
```

### Component responsibilities

#### `Eussiror` (lib/eussiror.rb)
Top-level module. Holds the singleton `configuration` object and exposes `.configure { |c| }`. All other components read `Eussiror.configuration`.

#### `Eussiror::Configuration`
Plain Ruby value object with attr_accessors for every option. Contains the two guard predicates used by `ErrorReporter`:
- `#valid?` — both token and repository are present
- `#reporting_enabled?` — valid config AND current Rails env is in `environments`

#### `Eussiror::Railtie`
Rails `Railtie` that runs one initializer: it inserts `Eussiror::Middleware` **before** `ActionDispatch::ShowExceptions` in the middleware stack. This positions our middleware as the outermost wrapper, so it sees the fully rendered 500 response on the way back out.

#### `Eussiror::Middleware`
Rack middleware with a standard `#call(env)` interface.
- On a normal response: passes through.
- On a 500 response with `env["action_dispatch.exception"]`: calls `ErrorReporter.report`.
- On a re-raised exception (non-standard setups): calls `ErrorReporter.report` before re-raising.

#### `Eussiror::Fingerprint`
Stateless module with a single public method: `.compute(exception) → String`.

The fingerprint is a 12-character hex prefix of a SHA256 digest computed from:
```
"#{exception.class.name}|#{exception.message[0,200]}|#{first_app_backtrace_line}"
```
Gem and stdlib lines are excluded when looking for the "first app line". This makes the fingerprint stable across deployments while being unique per error location.

The fingerprint is embedded as an HTML comment in the issue body:
```
<!-- eussiror:fingerprint:a1b2c3d4e5f6 -->
```

#### `Eussiror::GithubClient`
Thin HTTP client wrapping three GitHub REST API v3 endpoints. Uses only `Net::HTTP` (stdlib). Requires a `token:` and `repository:` at construction time.

| Method | Endpoint | Purpose |
|---|---|---|
| `#find_issue(fingerprint)` | `GET /search/issues` | Returns issue number or `nil` |
| `#create_issue(title:, body:, ...)` | `POST /repos/{owner}/{repo}/issues` | Returns new issue number |
| `#add_comment(issue_number, body:)` | `POST /repos/{owner}/{repo}/issues/{n}/comments` | Returns comment id |

#### `Eussiror::ErrorReporter`
Stateless module that orchestrates the full reporting flow. Called by the middleware.

1. Checks `Eussiror.configuration.reporting_enabled?` — returns early if not.
2. Checks `ignored_exceptions` — returns early if matched.
3. Dispatches in a `Thread.new` when `config.async` is `true` (default), or inline otherwise.
4. Computes fingerprint → searches GitHub → creates issue or adds comment.
5. All GitHub errors are rescued and emitted as `warn` messages — the gem **never crashes your app**.

#### `Eussiror::Generators::InstallGenerator`
Standard `Rails::Generators::Base` subclass. Copies `templates/initializer.rb.tt` to `config/initializers/eussiror.rb` using Thor's `template` method. Supports `rails destroy eussiror:install` for clean uninstallation.

### Testing approach

- **Unit specs**: each component is tested in isolation. `GithubClient` uses `WebMock` to stub HTTP calls. `ErrorReporter` uses RSpec doubles for `GithubClient`.
- **Generator spec**: uses Rails generator test helpers (`prepare_destination`, `run_generator`).
- **Appraisals**: the `Appraisals` file defines three gemfiles (`rails-7.2`, `rails-8.0`, `rails-8.1`) so the full test suite runs against each supported Rails version.

---

## Development

```bash
# Clone and install
git clone https://github.com/EquipeTechnique/eussiror.git
cd eussiror
bundle install

# Run tests against all Rails versions
bundle exec appraisal install
bundle exec appraisal rspec

# Run tests against a specific Rails version
bundle exec appraisal rails-8.0 rspec

# Run the linter
bundle exec rubocop

# Run the linter with auto-correct
bundle exec rubocop -A
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Write tests for your change
4. Make the tests pass: `bundle exec appraisal rspec`
5. Make the linter pass: `bundle exec rubocop`
6. Open a pull request against `main`

Please follow the existing code style. All public behaviour must be covered by specs.

---

## License

The gem is available as open source under the [MIT License](LICENSE).

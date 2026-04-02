# Eussiror

**Maintainer:** [@tracyloisel](https://github.com/tracyloisel)

[![Gem Version](https://img.shields.io/gem/v/eussiror.svg)](https://rubygems.org/gems/eussiror)
[![CI](https://github.com/EquipeTechnique/eussiror/actions/workflows/ci.yml/badge.svg)](https://github.com/EquipeTechnique/eussiror/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Eussiror** automatically creates GitHub issues when your Rails application raises an unhandled exception — whether from an HTTP request, an ActiveJob, Action Cable, or any other Rails execution context. If the same error already has an open issue, it adds a comment with the new occurrence instead — keeping your issue tracker clean and deduplicated.

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
| Ruby | 3.2 |
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

The generator creates `config/initializers/eussiror.rb` with all available options commented out and prints a short **post-install notice** in the terminal (next steps, token safety, `issue_privacy`).

To undo the installation:

```bash
rails destroy eussiror:install
```

---

## Configuration

Edit the generated initializer (`config/initializers/eussiror.rb`). Every assignable option is listed below.

```ruby
# config/initializers/eussiror.rb
Eussiror.configure do |config|
  # --- GitHub (required for reporting) ---
  config.github_token = ENV["GITHUB_TOKEN"]
  config.github_repository = "your-org/your-repo"

  # --- Where and how to report ---
  config.environments = %w[production]
  # config.issue_privacy = :minimal   # :minimal | :standard | :full — see "Issue privacy"
  config.async = true                 # false = synchronous (e.g. tests)

  # Also report errors caught by Rails.error.handle (default: false — only unhandled)
  # config.report_handled_errors = false

  # --- Issue metadata (optional) ---
  # config.labels = %w[bug automated]
  # config.assignees = []             # GitHub usernames (logins), not display names

  # --- Filtering (optional) ---
  # config.ignored_exceptions = %w[ActionController::RoutingError]
end
```

### Assignable options (`Eussiror.configure`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `github_token` | String | `nil` | Personal access token (classic `repo`, or fine-grained with Issues read/write on the target repo). **Required for any GitHub activity:** if blank, reporting is disabled. |
| `github_repository` | String | `nil` | Repository in `owner/repo` form. **Required with `github_token`** for reporting. |
| `environments` | Array of String | `["production"]` | Rails/Rack env names where reporting runs. Current env comes from `Rails.env` (Rails) or `ENV["RAILS_ENV"]` (default `"development"`). |
| `issue_privacy` | Symbol or String | `:minimal` | How much request/user context is copied into issue bodies and occurrence comments. Must be `minimal`, `standard`, or `full` (setter raises `ArgumentError` otherwise). See **Issue privacy** below. |
| `async` | Boolean | `true` | If `true`, `ErrorReporter` runs in a `Thread`; if `false`, reporting is synchronous (useful in tests or strict ordering). |
| `report_handled_errors` | Boolean | `false` | When `true`, errors caught by `Rails.error.handle` are also reported (by default only unhandled errors trigger a GitHub issue). |
| `labels` | Array of String | `[]` | Labels applied to **new** issues created by Eussiror (must exist on the repo). |
| `assignees` | Array of String | `[]` | GitHub **login** usernames assigned to new issues (empty = none). |
| `ignored_exceptions` | Array of String | `[]` | Exception **class names** to never report (e.g. `"ActionController::RoutingError"`). Unknown class names are ignored safely. |

Reporting runs only when **`#reporting_enabled?`** is true: configuration is **`#valid?`** (both `github_token` and `github_repository` non-blank after strip) **and** the current environment is listed in `environments`.

### Read-only and predicates (`Eussiror.configuration`)

These are not set in the initializer; they are useful for debugging or tests.

| Method | Returns | Description |
|--------|---------|-------------|
| `#environment_name` | String | Label for the current environment (same source as the env guard: `Rails.env` or `ENV["RAILS_ENV"]`). Shown in GitHub issue **Context**. |
| `#issue_privacy` | Symbol | Current privacy level after assignment (`:minimal`, `:standard`, or `:full`). |
| `#valid?` | Boolean | `true` if `github_token` and `github_repository` are both non-blank. |
| `#reporting_enabled?` | Boolean | `true` if `#valid?` and the current env is in `environments`. |

### Issue privacy

GitHub issues may be visible to people outside your core team (public repo, or future collaborators). **`issue_privacy`** controls how much context is copied into each issue:

| Value | Request in issue | User in issue | Typical use |
|-------|------------------|---------------|-------------|
| `:minimal` | HTTP method + path only | Never | Public repos, OSS, minimal footprint (default) |
| `:standard` | Also Remote IP and `User-Agent` when present in the Rack `env` | Never | Private repo, ops-friendly debugging |
| `:full` | Same as `:standard` | **User** section if you set Rack keys below | Private repo, team accepts user context in issues |

### Optional user context (Rack `env`)

When `issue_privacy` is `:full`, set these from your middleware (after authentication):

| Key | Meaning |
|-----|---------|
| `env["eussiror.user_id"]` | Stable user identifier (e.g. database id) |
| `env["eussiror.user_label"]` | Optional human-readable label (e.g. email or login) — only if your policy allows it |

### Context normalization

`Rails.error` can provide context in multiple shapes (flat hash, symbol keys, nested env/request, request object). Eussiror normalizes this before formatting issues/comments.

Recognized families of keys (first non-empty wins):
- **Request method/path:** `REQUEST_METHOD` / `PATH_INFO` (string or symbol), nested `env`/`rack`, request object (`request_method`, `fullpath`, `path`)
- **IP/user-agent:** `REMOTE_ADDR` / `HTTP_USER_AGENT`, nested `headers["User-Agent"]`, request object (`remote_ip`, `user_agent`, `ip`)
- **User fields:** `eussiror.user_id`, `eussiror.user_label`, plus `user_id` / `user_label` fallbacks

Explicit top-level keys win over nested values when both are present.

**Release** in the issue **Context** section is taken from the first non-empty environment variable among: `RELEASE` (recommended explicit override), then `SOURCE_VERSION` (Scalingo and others), `HEROKU_SLUG_COMMIT`, `RAILWAY_GIT_COMMIT_SHA`, `RENDER_GIT_COMMIT`, `REVISION`, `GIT_COMMIT`, `CI_COMMIT_SHA` (GitLab CI, etc.), `GITHUB_SHA` (GitHub Actions).

---

## How it works

Eussiror subscribes to **`Rails.error`** (`ActiveSupport::ErrorReporter`, available since Rails 7.1). Rails wraps every execution context — HTTP requests, ActiveJob, Action Cable, etc. — in this reporter, so Eussiror catches exceptions regardless of origin.

1. An unhandled exception (or a handled one if `report_handled_errors` is enabled) reaches `Rails.error`.
2. `Eussiror::ErrorSubscriber` receives the exception with its `severity`, `source`, and `context`.
3. A **fingerprint** is computed from the exception class, message, and first application backtrace line.
4. The GitHub API is searched for an open issue containing that fingerprint.
5. If **no issue exists** → a new issue is created with structured details.
6. If **an issue exists** → a comment with the new occurrence is added.

The issue title includes a **source tag** (`[request]`, `[job]`, `[cable]`, or `[error]`) so you can tell at a glance where the exception came from. Source classification uses a hybrid strategy:
- strict mapping for known Rails sources,
- heuristic fallback using source prefixes/contains (`ActiveJob`, `ActionCable`, `ActionDispatch`/`Rack`),
- final fallback to `[error]`.

### Example GitHub issue

**Title:** `[request] RuntimeError: something went wrong`

**Body:**
```
## Error Details

**Exception:** `RuntimeError`
**Message:** something went wrong
**First occurrence:** 2026-02-26 10:30:00 UTC

## Context

**Environment:** `production`
**Source:** `request` (omitted when the source is the default "error")
**Release:** `abc123` (when a release env var from the list in **Optional user context** is set)

## User

(Only when issue_privacy is :full and eussiror.user_* keys are set.)

## Request

**Request:** `GET /dashboard`
**Remote IP:** 1.2.3.4 (only when issue_privacy is :standard or :full)
**User-Agent:** … (same)

## Backtrace

app/controllers/dashboard_controller.rb:42:in 'index'
...
```

### Example occurrence comment

With `:minimal` (default):

```
**New occurrence:** 2026-02-26 14:55:02 UTC

**Request:** `GET /dashboard`
```

With `:standard` or `:full`, Remote IP and User-Agent are included when present; with `:full`, **User id** appears when `env["eussiror.user_id"]` is set.

---

## GitHub token setup

Eussiror needs a **GitHub token** to create issues on your behalf. Think of it like a password that lets the gem talk to GitHub for you — but you only use it in your app, never share it with anyone.

### Step-by-step: how to create your token

1. **Log in to GitHub**
   Go to [github.com](https://github.com) and sign in.

2. **Open your profile menu**
   Click your profile picture (top-right corner) → **Settings**.

3. **Go to Developer settings**
   In the left sidebar, scroll down to the bottom → **Developer settings**.

4. **Choose Personal access tokens**
   Click **Personal access tokens** → choose either **Tokens (classic)** or **Fine-grained tokens** (see below).

5. **Create a new token**
   Click **Generate new token** (or **Generate new token (classic)**).

6. **Configure the token**

   **If you chose Classic:**
   - Give it a name (e.g. `Eussiror for my-app`)
   - Set an expiration (e.g. 90 days, or No expiration if you prefer)
   - Check the **repo** scope (this allows reading and writing issues)

   **If you chose Fine-grained:**
   - Give it a name (e.g. `Eussiror for my-app`)
   - Under **Repository access**, select **Only select repositories** and pick your repo
   - Under **Permissions → Repository permissions**, set **Issues** to **Read and write**

7. **Generate and copy**
   Click **Generate token**.
   **Important:** Copy the token immediately — GitHub will only show it once. It looks like `ghp_xxxxxxxxxxxxxxxxxxxx`.

8. **Store it safely**
   Never put the token in your code. Use an environment variable:

   ```bash
   # In .env (or your secrets manager)
   GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
   ```

   Then in your initializer: `config.github_token = ENV["GITHUB_TOKEN"]`.

### Quick reference

| Option | Where to find it | Permission needed |
|--------|------------------|-------------------|
| **Classic** | Settings → Developer settings → Personal access tokens → Tokens (classic) | `repo` scope |
| **Fine-grained** | Settings → Developer settings → Personal access tokens → Fine-grained tokens | Issues: Read and write for your repo |

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
    ├── railtie.rb                      # Rails integration: subscribes to Rails.error
    ├── error_subscriber.rb             # ActiveSupport::ErrorReporter subscriber
    ├── fingerprint.rb                  # Computes a stable SHA256 fingerprint per exception type
    ├── github_client.rb                # GitHub REST API v3 calls via Net::HTTP
    ├── issue_formatting.rb             # Issue body and occurrence comment text
    ├── release_env.rb                  # Optional release label from ENV (PaaS/CI keys)
    └── error_reporter.rb               # Orchestrator: fingerprint → search → create or comment

lib/generators/eussiror/install/
├── install_generator.rb                # `rails generate eussiror:install`
└── templates/initializer.rb.tt         # Template for config/initializers/eussiror.rb
```

### Error flow

```
Any Rails execution context
(HTTP request, ActiveJob, Action Cable, Rake, etc.)
    │
    ▼  unhandled exception
Rails.error (ActiveSupport::ErrorReporter)
    │
    ▼  report(error, handled:, severity:, context:, source:)
Eussiror::ErrorSubscriber
    │  filters: handled? severity == :error?
    ▼
Eussiror::ErrorReporter.report(exception, context, source:)
    │
    ├── Fingerprint.compute(exception)
    ├── GithubClient.find_issue(fingerprint)
    │     found  → GithubClient.add_comment (occurrence)
    │     absent → GithubClient.create_issue (structured body)
    │
    ▼
GitHub Issues
```

### Component responsibilities

#### `Eussiror` (lib/eussiror.rb)
Top-level module. Holds the singleton `configuration` object and exposes `.configure { |c| }`. All other components read `Eussiror.configuration`.

#### `Eussiror::Configuration`
Plain Ruby value object with attr_accessors for every option. Exposes `#environment_name` for issue bodies. Contains the two guard predicates used by `ErrorReporter`:
- `#valid?` — both token and repository are present
- `#reporting_enabled?` — valid config AND current Rails env is in `environments`

`#issue_privacy` must be `:minimal`, `:standard`, or `:full` (setter raises `ArgumentError` otherwise).

#### `Eussiror::Railtie`
Rails `Railtie` that runs one initializer: it registers `Eussiror::ErrorSubscriber` with `Rails.error.subscribe`, hooking into every execution context Rails wraps (requests, jobs, channels, etc.).

#### `Eussiror::ErrorSubscriber`
Implements the `ActiveSupport::ErrorReporter` subscriber interface (`#report(error, handled:, severity:, context:, source:)`). Filters out handled errors (unless `report_handled_errors` is enabled) and non-`:error` severities, then delegates to `ErrorReporter`.

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
Stateless module that orchestrates the full reporting flow. Called by `ErrorSubscriber`.

1. Checks `Eussiror.configuration.reporting_enabled?` — returns early if not.
2. Checks `ignored_exceptions` — returns early if matched.
3. Maps the `source` string to a human-readable tag (`[request]`, `[job]`, `[cable]`, or `[error]`).
4. Dispatches in a `Thread.new` when `config.async` is `true` (default), or inline otherwise.
5. Computes fingerprint → searches GitHub → creates issue (structured body: Error Details, Context, optional User, Request, Backtrace) or adds an occurrence comment.
6. All GitHub errors are rescued and emitted as `warn` messages — the gem **never crashes your app**.

#### `Eussiror::Generators::InstallGenerator`
Standard `Rails::Generators::Base` subclass. Copies `templates/initializer.rb.tt` to `config/initializers/eussiror.rb` using Thor's `template` method, then prints a **post-install notice** (`show_post_install_notice`). Supports `rails destroy eussiror:install` for clean uninstallation.

### Testing approach

- **Unit specs**: each component is tested in isolation. `GithubClient` uses `WebMock` to stub HTTP calls. `ErrorReporter` and `ErrorSubscriber` use RSpec doubles.
- **Generator spec**: uses Rails generator test helpers (`prepare_destination`, `invoke_all`) and asserts post-install output.
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

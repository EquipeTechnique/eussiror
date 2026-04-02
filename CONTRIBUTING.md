# Contributing

Thank you for contributing to `eussiror`.

## Development Setup

```bash
bundle install
bundle exec appraisal install
```

## Quality Checks (required)

```bash
bundle exec rubocop
bundle exec appraisal rspec
```

- CI must pass before merge.
- Keep branch changes focused and small when possible.
- Update `CHANGELOG.md` for user-visible changes.

## Pull Request Expectations

- Explain the WHY of the change, not only the WHAT.
- Include or update tests for behavioral changes.
- Keep public API changes intentional and documented.
- Avoid unrelated refactors in the same PR.

## Spec Naming Tone Guide

1. **Playful, but explicit**  
   Fun fixture names are welcome if test intent stays obvious on first read.

2. **One universe, not random jokes**  
   Use a coherent naming theme across specs (investigation/X-Files style is acceptable).

3. **Behavior first, flavor second**  
   If a fun name hurts clarity, replace it with a neutral one.

4. **Constrain fun to test data**  
   Keep playful naming in specs/support fixtures only. Production code and public API stay neutral.

5. **Keep names deterministic and reusable**  
   Reuse canonical agent/path/example strings to make diffs and reviews easier.

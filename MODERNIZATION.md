# Modernization Plan: `unit`

Status: **Draft** · Last meaningful commit: 2015-06-09 · Plan written: 2026-06

`unit` adds scientific/computational units to Ruby (`1.meter.in_kilometer`,
`Unit('1 m/s^2')`, unit-aware arithmetic and conversions). The core library is
small (~600 LOC plus YAML unit definitions), dependency-free at runtime, and
still loads cleanly on modern Ruby. What has rotted is everything *around* the
code — CI, badges, gemspec metadata — plus two genuine correctness bugs. This
document is the roadmap for bringing it back to a releasable, maintained state.

## Current health snapshot

| Area | State | Notes |
| --- | --- | --- |
| Core library | 🟢 Good | Loads on Ruby 4.0.5 with **zero** warnings under `ruby -w`. Clean architecture. |
| Test suite | 🟡 2 failures | `49 examples, 2 failures` via `bundle exec rake`. Both are real bugs (see below). |
| CI | 🔴 Dead | `.travis.yml` targets EOL Rubies (1.9.3–2.2, rbx, jruby-19mode); Travis CI is defunct for OSS. |
| README badges | 🔴 Dead | Gemnasium (shut down), `badge.fury.io/*.png`, Code Climate, `travis-ci.org` all gone. |
| Gemspec | 🟡 Warnings | No `required_ruby_version`; `description` == `summary`; non-reproducible `s.date`; unpinned `rspec`. |
| Releases / tags | 🟡 Out of sync | Only `v0.4.1` is tagged; code and RubyGems are at `0.5.0`. |
| Provenance | ℹ️ | `upstream` = `minad/unit` (Daniel Mendler); `origin` = `nertzy/unit`. |

## Known correctness bugs

Both failing specs share one root cause: **`Unit#normalize` mutates its
receiver** instead of operating on a copy.

- `spec/unit_spec.rb:110` — `#normalize` "should not modify the receiver":
  after `Unit(1, 'joule').normalize`, the original is mutated into
  `1000 g·m^2·s^-2`.
- `spec/unit_spec.rb:152` — `(Unit('5 cm') - Unit('1 cm')).to_s` returns
  `"(1/25) m"` instead of `"4 cm"`. `+`/`-` call `.in(self)` to convert back to
  the caller's unit, but the normalize mutation corrupts that round-trip, so
  **subtraction/addition silently lose the chosen unit**.

Root cause: `lib/unit/class.rb` `normalize` does `@normalized ||= dup.normalize!`,
but `initialize_copy` only shallow-dups `@unit` (an array of arrays).
`reduce!` / `normalize!` then mutate inner arrays still shared with the original.
Likely surfaced by `Numeric`/`Rational`/`dup` behavior changes in newer Ruby.

## Roadmap

Each step is intended to be its own focused commit. Following the BDD/TDD
workflow: drive the bug fix from the already-failing specs, then layer infra and
metadata changes on top.

### 1. Fix the `normalize` mutation bug 🔴 (highest priority)
- [ ] Deep-dup `@unit` (and reset memoized `@normalized`) in `initialize_copy`
      so `normalize` never touches its receiver.
- [ ] Confirm `bundle exec rake` reports `49 examples, 0 failures`.
- [ ] Add a focused regression spec for add/subtract preserving the caller's
      unit (e.g. `5 cm - 1 cm == 4 cm` round-trips as `cm`).

### 2. Replace Travis with GitHub Actions
- [ ] Add `.github/workflows/ci.yml` running `bundle exec rake` on a current
      Ruby matrix (3.2, 3.3, 3.4, and `head`).
- [ ] Delete `.travis.yml`.
- [ ] (Optional) Add a JRuby/TruffleRuby leg once the suite is green on MRI.

### 3. Refresh the README
- [ ] Remove the Gemnasium, Travis, Code Climate, and Fury PNG badges.
- [ ] Add a working RubyGems version badge and a GitHub Actions status badge.
- [ ] Verify all usage examples still run as written (they double as docs).

### 4. Tidy the gemspec
- [ ] Declare `required_ruby_version` (proposed floor: `>= 3.0`).
- [ ] Give `description` real prose distinct from `summary`.
- [ ] Remove `s.date = Date.today.to_s` (RubyGems sets this; it breaks
      reproducible builds).
- [ ] Pin dev dependency `rspec` to `~> 3.0` (suite is already RSpec 3 syntax).

### 5. Release hygiene
- [ ] Add `CHANGELOG.md` documenting the bug fix and modernization.
- [ ] Re-sync git tags (tag the current `0.5.0`), then cut the next maintenance
      release (likely `0.5.1` for the bug fix).
- [ ] Add a `.ruby-version` / confirm `mise` config for a pinned dev Ruby.

## Out of scope (for now)

- New unit systems or features — this pass is purely revival/maintenance.
- Performance work on the parser in `lib/unit/system.rb`.
- API changes; keep `0.5.x` backward compatible.

## Open questions

- Minimum supported Ruby — is `>= 3.0` acceptable, or do we need to support
  older still-in-use versions?

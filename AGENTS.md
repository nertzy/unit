# AGENTS.md

Guidance for working effectively in the `unit` gem. See `README.markdown` for
user-facing usage.

## What this is

`unit` adds scientific and computational units to Ruby: unit-aware arithmetic,
conversions, and expression parsing (`Unit('1 m/s^2')`), plus an optional DSL
(`1.meter.in_kilometer`). It is pure Ruby with no runtime dependencies.

## Setup

- Ruby >= 3.3 (see `required_ruby_version` in `unit.gemspec`).
- `bundle install`

## Running tests

- `bundle exec rake` runs the full suite. It deliberately runs the specs
  **twice**:
  - `rake spec:no_dsl` excludes `:dsl`-tagged examples and does **not** load
    `lib/unit/dsl.rb`, verifying the core works without the DSL.
  - `rake spec:dsl` loads the DSL and runs everything.
- This split exists because the DSL monkey-patches `Numeric` and is **not**
  loaded by `require 'unit'`; it must be required explicitly (`require
  'unit/dsl'`). See `spec/spec_helper.rb`.
- Single file or example: `bundle exec rspec spec/unit_spec.rb -e "supports addition"`.

## Layout

- `lib/unit.rb` — entry point. Requires `version`, `class`, `system`,
  `constructor`. Does **not** load the DSL.
- `lib/unit/class.rb` — the `Unit` class (a `Numeric` subclass): arithmetic,
  `normalize`, `in`/conversions, comparison, and formatting.
- `lib/unit/system.rb` — `Unit::System`: loads unit and factor definitions from
  YAML, parses unit expressions, and defines the default `SI` system.
- `lib/unit/constructor.rb` — the top-level `Unit(...)` constructor.
- `lib/unit/dsl.rb` — optional DSL adding methods to `Numeric` and `Unit`
  (`1.meter`, `.in_kilometer`, ...). Opt in with `require 'unit/dsl'`.
- `lib/unit/systems/*.yml` — unit definitions. The default system loads `si`,
  `binary`, `degree`, and `time`; `scientific`, `imperial`, and `misc` are
  available on demand.

## Things to know before editing

- **`Unit` is a `Numeric` subclass, and modern Ruby treats numerics as immutable
  value objects** — `dup`/`clone` return `self` by default. `Unit` overrides
  `#dup` precisely so copy-based methods like `#normalize` don't mutate the
  receiver. Don't reintroduce reliance on the default `dup`.
- **Not every unit is loaded by `require 'unit'`.** Only SI + binary + degree +
  time load by default; units such as `MeV` (scientific) need their system
  loaded first, e.g. `Unit.default_system.load(:scientific)`.
- **Adding a unit system**: drop a YAML file under `lib/unit/systems/` and load
  it via `Unit::System#load`.
- **Packaging**: `unit.gemspec` ships only runtime files
  (`Dir['lib/**/*.{rb,yml}']` plus `README.markdown` and `LICENSE`); specs, CI
  config, and docs are intentionally excluded from the built gem.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `bundle exec rake` against Ruby
3.3, 3.4, 4.0, and `head` on every push and pull request.

## Releasing

1. Bump `Unit::VERSION` in `lib/unit/version.rb`.
2. Add a `CHANGELOG.md` entry for the new version.
3. Tag `vX.Y.Z`, then `gem build unit.gemspec && gem push unit-X.Y.Z.gem`.

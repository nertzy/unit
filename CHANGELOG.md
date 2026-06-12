# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `Unit#normalize` no longer mutates its receiver. Modern Ruby treats `Numeric`
  and its subclasses as immutable value objects, so `dup`/`clone` return `self`;
  `normalize` relied on `dup` returning a fresh copy, so it — and the `#in`
  conversions built on it — mutated the original unit in place. As a result,
  arithmetic silently lost the caller's chosen unit, e.g.
  `Unit('5 cm') - Unit('1 cm')` rendered as `(1/25) m` instead of `4 cm`.
- Symbols whose glyphs fall outside the old ASCII character class (`Ω`, `%`,
  `℃`, `℉`, `π`, `Å`, arcminute/arcsecond quotes, `a.u.`, etc.) were silently
  dropped to a dimensionless value instead of being parsed correctly. The lexer
  now tokenizes any run of non-operator, non-whitespace characters as a symbol,
  so every registered unit — including ones whose symbol uses a non-ASCII glyph,
  and ones loaded at runtime — is recognised without changes to the gem.

### Changed

- **Breaking:** parsing an unrecognised unit symbol now always raises
  `TypeError: Undefined unit …` instead of sometimes silently yielding a
  dimensionless value. Previously only unknown ASCII symbols failed loudly;
  unknown non-ASCII glyphs were dropped by the lexer, so `Unit(1, 'λ')` returned
  a unitless `1`, `Unit(1, 'm λ')` silently became `1 m`, and `Unit(1, 'm/λ')`
  raised a misleading `Unexpected token /`. Unknown symbols of any kind now fail
  loudly and name the offending symbol.
- Modernized the gemspec to current RubyGems/Bundler guidance: a real
  description distinct from the summary, an explicit `Dir`-based file manifest
  (development files no longer ship in the packaged gem), `require_relative`,
  `source_code_uri`/`bug_tracker_uri` metadata, `rubygems_mfa_required`, and
  pessimistic dev-dependency version pins.
- Replaced the retired Travis CI configuration with a GitHub Actions workflow
  that runs the suite on Ruby 3.3, 3.4, 4.0, and head.
- Refreshed the README status badges (RubyGems version and GitHub Actions CI).

### Removed

- Dropped support for Ruby older than 3.3 (`required_ruby_version >= 3.3`).

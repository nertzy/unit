# Numeric Compatibility Surface Area

This document surveys the full `Numeric` (and common Ruby number type) API surface
against `Unit`'s behaviour, identifying gaps in test coverage and known issues.

---

## How the inheritance works

`Unit < Numeric`. `Numeric` provides a large default implementation; `Unit`
overrides a focused subset. Everything else is inherited as-is, which means the
behaviour of each inherited method depends entirely on what `Numeric`'s
implementation does when it calls back into `Unit` — often `<=>`, `to_i`, or
`to_f`.

---

## Methods Unit explicitly overrides

These exist in `lib/unit/class.rb` and have test coverage:

| Method | Notes |
|---|---|
| `*`, `/`, `+`, `-`, `**`, `-@`, `+@` | Arithmetic — well-tested |
| `==`, `eql?`, `<=>` | Equality and ordering — well-tested, including edge cases |
| `hash` | Defined as `[value, unit].hash` — satisfies `eql?`/`hash` contract |
| `abs` | Preserves unit |
| `zero?`, `positive?`, `negative?` | Delegate to `value` |
| `numerator`, `denominator` | Delegate to `value` |
| `finite?`, `infinite?` | Delegate to `value` when `value` responds; correct fallbacks otherwise |
| `remainder` | Explicit implementation: `self - (self / other).truncate * other` |
| `ceil`, `floor`, `truncate` | Override to preserve unit; accept `ndigits` argument |
| `round` | Preserves unit; accepts `ndigits` and `half:` keyword |
| `to_i`, `to_f` | Strip unit, return bare numeric |
| `coerce` | Enables Integer/Float on left-hand side |
| `dup`, `initialize_copy`, `freeze` | Immutability contract — tested |
| `inspect`, `to_s`, `to_tex` | Formatting |
| `approx` | Returns Float-valued unit |

---

## Inherited Numeric methods — behaviour inventory

### Group 1: Work correctly, with tests

These were previously untested; coverage was added alongside the bug fixes.

| Method | Behaviour | Notes |
|---|---|---|
| `+@` | Returns `self` | |
| `abs2` | Returns `Unit(value**2, unit**2)` — e.g. `Unit(3,'m').abs2 == Unit(9,'m^2')` | Dimensionally correct via `self * self.conj` |
| `nonzero?` | Returns `self` or `nil` | |
| `integer?` | Always `false` | `Unit` is not `Integer` |
| `real?` | Always `true` | |
| `real` | Returns `self` | |
| `imag` / `imaginary` | Returns `0` | |
| `conj` / `conjugate` | Returns `self` | |
| `rect` / `rectangular` | Returns `[self, 0]` | |
| `modulo` / `%` | Preserves unit; result sign matches divisor | |
| `divmod` | Returns `[floored_quotient, remainder]`; quotient is dimensionless for compatible units | |
| `div` | Floored integer quotient; compatible units → dimensionless; incompatible → combined dimension | Unit-preserving as side-effect of overriding `floor` |
| `fdiv(scalar)` | Returns bare `Float` (unit stripped) — e.g. `Unit(3,'m').fdiv(2) => 1.5` | See note below |
| `to_int` | Strips unit, returns `Integer` (same as `to_i`) | |
| `between?` | Works via `<=>` | |
| `clamp` | Works for both two-arg and Range forms | |

---

### Group 2: Work correctly, still untested

| Method | Behaviour | Notes |
|---|---|---|
| `to_c` | Returns `(Unit("3 m")+0i)` | Works via `Numeric#to_c`; unit ends up inside the complex |
| `clone` | Returns a distinct copy (not `self`) | Unlike `dup` on a plain Numeric; `Unit` overrides `initialize_copy` so clone behaves normally |

`Kernel` conversion functions work and strip the unit:

```ruby
Float(Unit(3.5, 'm'))    # => 3.5    (bare Float)
Integer(Unit(3, 'm'))    # => 3      (bare Integer)
Rational(Unit(3, 'm'))   # => (3/1)  (bare Rational)
```

No tests for any of these.

---

### Group 3: Known remaining issues

#### `fdiv` with a Unit divisor returns a wrong dimension

`Numeric#fdiv` is implemented as `self.to_f / other`. `to_f` strips the unit
from `self` (yielding e.g. `3.0`), then `3.0 / Unit(2.0,'m')` goes through
coerce, producing `Unit(1.5, 'm^-1')` instead of the correct `1.5`:

```ruby
Unit(3, 'm').fdiv(Unit(2, 'm'))    # => Unit("1.5 m^-1")  ← wrong (should be 1.5)
Unit(3, 'm').fdiv(2)               # => 1.5               ← correct
```

`fdiv` should be overridden to delegate to `(self / other).to_f` for the unit
case, or restricted to scalar divisors only.

#### `magnitude` raises but `abs` works — asymmetry

`abs` is overridden in `Unit` and works correctly. `magnitude` is inherited from
`Numeric` (it is an alias for `abs` in `Numeric` but `Numeric#magnitude` calls
`abs` on `self`, which goes through `<=>` internally on some paths) and raises
`ArgumentError` for dimensional units:

```ruby
Unit(3, 'm').abs        # => Unit("3 m")   ✓
Unit(3, 'm').magnitude  # => ArgumentError ✗
```

The fix is to alias `magnitude` to `abs` in `Unit`.

#### `step` raises for dimensional units

`Numeric#step` compares the step value against `Integer` internally, triggering
the dimensional `<=>` guard:

```ruby
Unit(0, 'm').step(Unit(3, 'm'), Unit(1, 'm')) { }
# => ArgumentError: comparison of Unit("1 m") with Integer failed
```

This could be fixed by overriding `step` to work directly on the value while
re-wrapping each yielded result, or by documenting it as unsupported.

#### `angle` / `arg` / `phase` / `polar` raise for dimensional units

All four call `self <=> 0` internally, which fails for dimensional units:

```ruby
Unit(3, 'm').angle    # => ArgumentError
Unit(3, 'm').polar    # => ArgumentError
```

For dimensionless units they work correctly. These are arguably correct
behaviour — a dimensional quantity doesn't have a phase angle — but they should
have tests confirming the error and documenting the intent.

---

### Group 4: Methods that raise by design (need confirming tests)

These raise for dimensional units in a principled way. Tests confirming the
error should be added so the behaviour is explicit and can't regress silently:

| Method | Behaviour |
|---|---|
| `angle` / `arg` / `phase` | `ArgumentError` — dimensional `<=>` 0 fails |
| `magnitude` | `ArgumentError` — should be aliased to `abs` (see above) |
| `polar` | `ArgumentError` — calls `angle` internally |
| `step` | `ArgumentError` — compares step value with `Integer` |
| `**` with a `Unit` exponent | `TypeError` — explicit guard in `Unit#**` |
| `+`, `-` with incompatible units | `IncompatibleUnitError` |

---

## Summary of issues (current state)

### Fixed

| # | Method(s) | Fix applied |
|---|---|---|
| 1 | `hash` | Defined as `[value, unit].hash` |
| 2 | `ceil`, `floor`, `truncate` | Overridden to preserve unit; consistent with `round` |
| 3 | `finite?`, `infinite?` | Overridden to delegate to `value` |
| 4 | `positive?`, `negative?` | Overridden to delegate to `value` |
| 5 | `numerator`, `denominator` | Overridden to delegate to `value` |
| 6 | `remainder` | Explicit implementation using `truncate` |
| 7 | `div` with incompatible units | Fixed as side-effect of `floor` override |
| 8 | `round(half:)` | Fixed — `round` now accepts `**opts` |

### Open

| # | Method(s) | Severity | Proposed fix |
|---|---|---|---|
| 9 | `fdiv` with Unit divisor | **Medium** — wrong dimension in result | Override `fdiv` to use `(self/other).to_f` |
| 10 | `magnitude` vs `abs` | **Low** — asymmetric; magnitude raises | `alias_method :magnitude, :abs` |
| 11 | `step` | **Low** — raises for all dimensional units | Override or document as unsupported |
| 12 | `angle`/`arg`/`phase`/`polar` | **Low** — raise, arguably correct | Add confirming tests |

### Untested working behaviour

| Area | Missing tests |
|---|---|
| `to_c` | Not tested |
| `clone` | Not tested |
| `Kernel` conversions (`Float()`, `Integer()`, `Rational()`) | Not tested |
| `angle`/`magnitude`/`step`/`polar` raise paths | Not tested (Group 4 above) |

---

## Ruby version compatibility (3.3 / 3.4 / 4.0)

The CI matrix covers Ruby 3.3, 3.4, 4.0, and `head`. The `Numeric`, `Float`,
`Integer`, `Rational`, and `Comparable` method sets are **identical** across
all three versions — no methods were added or removed between 3.3 and 4.0.

However, there are two **behavioural changes** that affect `Unit`.

### `Integer#**` / `Rational#**` overflow changed in Ruby 3.4

**Ruby 3.3:** raising an integer to a very large power silently overflowed to
`Float::INFINITY`, emitting a warning at `$VERBOSE` level.

**Ruby 3.4+:** the result stays an `Integer` (arbitrary-precision bignum);
the overflow-to-Float path was removed.

`Unit#**` passes the exponent computation through to the underlying `@value`,
so this change propagates directly:

```ruby
# Ruby 3.3
Unit(2, 'm') ** 100_000_000
# warning: in a**b, b may be too big
# => Unit("Infinity m^100000000")   ← value is Float::INFINITY

# Ruby 3.4+
Unit(2, 'm') ** 100_000_000
# => Unit("36846659369…  m^100000000")  ← value is a bignum Integer
```

Any test asserting that very-large-exponent `Unit#**` produces `Infinity` passes
on 3.3 and fails on 3.4+. **Version-gate** such tests, or confine them to
Float-valued units — `Unit(2.0,'m') ** 100_000_000` still yields `Infinity` on
all versions because it goes through `Float#**`.

Note: `Rational#**` follows the same rule — extremely large `Rational` values
that previously returned `Float::NAN` or `Float::INFINITY` now return a
(potentially huge) `Rational` on 3.4+.

### `Kernel#Float()` is more permissive in Ruby 3.4

**Ruby 3.3:** `Float("1.")` and `Float("1.E-1")` raise `ArgumentError`.
**Ruby 3.4+:** both are accepted.

`Unit` does not call `Kernel#Float()` internally, so this has **no direct
impact**. Worth verifying in parser tests if `Unit("1. m")` is a supported
input form.

### Version compatibility summary

| Area | 3.3 | 3.4 | 4.0 | Notes |
|---|---|---|---|---|
| `Numeric` method set | identical | identical | identical | no additions or removals |
| `Integer#**` overflow | → `Float::INFINITY` + warning | → bignum `Integer` | → bignum `Integer` | affects `Unit#**` with Integer value |
| `Rational#**` overflow | → `Float::NAN` / `Float::INFINITY` | → large `Rational` | → large `Rational` | affects `Unit#**` with Rational value |
| `Float#**` overflow | → `Float::INFINITY` | → `Float::INFINITY` | → `Float::INFINITY` | **unchanged** |
| `Kernel#Float("1.")` | `ArgumentError` | `1.0` | `1.0` | no internal Unit impact |
| All other inherited behaviours | identical | identical | identical | |

---

## Remaining suggested test additions

```ruby
describe "#to_c" do ... end                      # Group 2: untested, works
describe "#clone" do ... end                     # Group 2: untested, works
describe "Kernel conversions" do                 # Group 2: Float(), Integer(), Rational()
describe "#fdiv with Unit divisor" do ... end    # Open issue 9
describe "#magnitude" do ... end                 # Open issue 10 (should alias abs)
describe "#step" do ... end                      # Open issue 11
describe "raises by design" do                   # Group 4: angle, polar, step, magnitude
describe "#** with large exponents" do ... end   # version-gated: 3.3 vs 3.4+
```

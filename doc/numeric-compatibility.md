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

## Design goal: Complex-valued units

Units with complex scalar values are explicitly supported. Electrical impedance,
phasors, and similar quantities are dimensional values with complex scalars:

```ruby
z = Unit(Complex(3, 4), 'ohm')
z.abs    # => Unit("5.0 Ω")
z.real   # => Unit("3 Ω")
z.imag   # => Unit("4 Ω")
z.conj   # => Unit("3-4i Ω")
z.real?  # => false
```

Methods that distinguish real from complex (`real?`, `real`, `imag`, `conj`,
`rect`) must delegate to `value` rather than returning `Numeric`'s unconditional
real-only defaults.

---

## Methods Unit explicitly overrides

These exist in `lib/unit/class.rb` and have test coverage:

| Method | Notes |
|---|---|
| `*`, `/`, `+`, `-`, `**`, `-@`, `+@` | Arithmetic — well-tested |
| `==`, `eql?`, `<=>` | Equality and ordering — well-tested, including edge cases |
| `hash` | `[self.class, value, unit].hash` — satisfies `eql?`/`hash` contract; `self.class` prevents bucket collisions with plain arrays of the same shape |
| `abs` | Preserves unit; for complex values delegates to `value.abs` (gives magnitude) |
| `real?` | Delegates to `value.real?` — `false` for complex-valued units |
| `real` | Returns `self` for real values; `Unit(value.real, unit)` for complex |
| `imag` / `imaginary` | Returns `0` for real values; `Unit(value.imag, unit)` for complex |
| `conj` / `conjugate` | Returns `self` for real values; `Unit(value.conj, unit)` for complex |
| `rect` / `rectangular` | Returns `[real, imag]` — unit-preserving in both components |
| `zero?`, `positive?`, `negative?` | Delegate to `value` |
| `finite?`, `infinite?` | Delegate to `value` when `value` responds; correct fallbacks otherwise |
| `numerator`, `denominator` | Inherited from `Numeric` via `to_r` (see below) |
| `to_r` | Raises `RangeError` for dimensional units (Complex precedent); converts normally for dimensionless; gives `numerator`/`denominator` for free |
| `to_i`, `to_f` | Raise `RangeError` for dimensional units (Complex precedent); convert normally for dimensionless |
| `remainder` | Explicit implementation: `self - (self / other).truncate * other` |
| `ceil`, `floor`, `truncate` | Override to preserve unit; accept `ndigits` argument |
| `round` | Preserves unit; accepts `ndigits` and `half:` keyword |
| `fdiv` | Returns `(self / other).approx` — unit-preserving with float value; fixes inherited `Numeric#fdiv` which called `self.to_f` (now raises for dimensional units) |
| `coerce` | Enables Integer/Float on left-hand side |
| `dup`, `initialize_copy`, `freeze` | Immutability contract — tested |
| `inspect`, `to_s`, `to_tex` | Formatting |
| `approx` | Returns Float-valued unit via `@value.to_f` |

---

## Inherited Numeric methods — behaviour inventory

### Group 1: Inherited, work correctly, with tests

| Method | Behaviour | Notes |
|---|---|---|
| `+@` | Returns `self` | |
| `abs2` | `Unit(value.abs2, unit**2)` — e.g. `Unit(3,'m').abs2 == Unit(9,'m^2')`; for complex values gives `\|z\|² · unit²` | Correct: `self * self.conj` |
| `nonzero?` | Returns `self` or `nil` | |
| `integer?` | Always `false` | `Unit` is not `Integer` |
| `modulo` / `%` | Preserves unit; result sign matches divisor | |
| `divmod` | Returns `[floored_quotient, remainder]`; quotient is dimensionless for compatible units | |
| `div` | Floored integer quotient; compatible units → dimensionless `Unit`; incompatible → combined dimension `Unit` | Unit-preserving as side-effect of `floor` override |
| `to_int` | Raises `RangeError` for dimensional units (calls `to_i` internally) | |
| `between?` | Works via `<=>` | |
| `clamp` | Works for both two-arg and Range forms | |

---

### Group 2: Inherited, work correctly, no tests yet

| Method | Behaviour | Notes |
|---|---|---|
| `to_c` | Returns `Complex`-wrapped unit value | Works via `Numeric#to_c`; unit ends up inside the complex |
| `clone` | Returns a distinct copy | `Unit` overrides `initialize_copy` so clone works normally |

`Kernel` conversion functions strip the unit and return a bare numeric:

```ruby
Float(Unit(3.5, 'm'))    # => 3.5    (bare Float — raises for dimensional same as to_f)
Integer(Unit(3, 'm'))    # => 3      (bare Integer — raises for dimensional same as to_i)
Rational(Unit(3, 'm'))   # => (3/1)  (bare Rational — raises for dimensional same as to_r)
```

No tests for any of these.

---

### Group 3: Known remaining issues

#### `magnitude` raises but `abs` works — asymmetry

`abs` is overridden and works correctly for both real and complex values.
`magnitude` is an alias for `abs` in `Numeric` but is not inherited as an alias
in `Unit` — it falls through to `Numeric#magnitude` which calls `abs` via a
path that internally uses `<=>`, raising `ArgumentError` for dimensional units:

```ruby
Unit(3, 'm').abs        # => Unit("3 m")   ✓
Unit(3, 'm').magnitude  # => ArgumentError ✗
```

Fix: `alias magnitude abs` in `Unit`.

#### `step` raises for dimensional units

`Numeric#step` compares the step value against `Integer` internally, triggering
the dimensional `<=>` guard:

```ruby
Unit(0, 'm').step(Unit(3, 'm'), Unit(1, 'm')) { }
# => ArgumentError: comparison of Unit("1 m") with Integer failed
```

Could be fixed by overriding `step` to iterate on the bare value and re-wrap
each yielded result, or documented as unsupported.

#### `angle` / `arg` / `phase` / `polar` raise for dimensional units

All four call `self <=> 0` internally, which fails for dimensional units:

```ruby
Unit(3, 'm').angle    # => ArgumentError
Unit(3, 'm').polar    # => ArgumentError
```

For dimensionless units they work correctly. These are arguably correct
behaviour — a dimensional quantity doesn't have a phase angle — but they should
have tests confirming the error and documenting the intent. Note: for
*complex-valued* dimensional units, `angle` and `polar` are well-defined;
this is a separate issue from the dimensional-scalar case.

---

### Group 4: Methods that raise by design (need confirming tests)

These raise for dimensional units in a principled way. Tests confirming the
error should be added so the behaviour is explicit and can't regress silently:

| Method | Behaviour |
|---|---|
| `angle` / `arg` / `phase` | `ArgumentError` — dimensional `<=>` 0 fails (real-valued units) |
| `magnitude` | `ArgumentError` — should be aliased to `abs` (see above) |
| `polar` | `ArgumentError` — calls `angle` internally |
| `step` | `ArgumentError` — compares step value with `Integer` |
| `**` with a `Unit` exponent | `TypeError` — explicit guard in `Unit#**` |
| `+`, `-` with incompatible units | `IncompatibleUnitError` |

---

## Summary of issues

### Fixed

| # | Method(s) | Fix |
|---|---|---|
| 1 | `hash` | `[self.class, value, unit].hash` — satisfies `eql?`/`hash` contract |
| 2 | `ceil`, `floor`, `truncate` | Overridden to preserve unit; consistent with `round` |
| 3 | `finite?`, `infinite?` | Delegate to `value` |
| 4 | `positive?`, `negative?` | Delegate to `value` |
| 5 | `numerator`, `denominator` | Fixed by defining `to_r`; both work via `Numeric#numerator` → `self.to_r` |
| 6 | `remainder` | Explicit implementation using `truncate` |
| 7 | `div` silent unit loss | Fixed as side-effect of `floor` override |
| 8 | `round(half:)` | `round` now forwards all args |
| 9 | `to_i` / `to_f` silent unit strip | Now raise `RangeError` for dimensional units (Complex precedent) |
| 10 | `fdiv` wrong dimension | Overridden as `(self / other).approx` |
| 11 | `real?`, `real`, `imag`, `conj`, `rect` | Delegate to `value` — correct for complex-valued units |

### Open

| # | Method(s) | Severity | Proposed fix |
|---|---|---|---|
| 12 | `magnitude` vs `abs` | **Low** — asymmetric; magnitude raises | `alias magnitude abs` |
| 13 | `step` | **Low** — raises for all dimensional units | Override or document as unsupported |
| 14 | `angle`/`arg`/`phase`/`polar` for complex-valued dimensional units | **Low** — raises via `<=>` but `angle` is well-defined for complex values | Override to use `value.angle` when `!value.real?` |

### Untested working behaviour

| Area | Missing tests |
|---|---|
| `to_c` | Not tested |
| `clone` | Not tested |
| `Kernel` conversions (`Float()`, `Integer()`, `Rational()`) | Not tested |
| `angle`/`magnitude`/`step`/`polar` raise paths | Not tested (Group 4 above) |
| `abs2` for complex-valued units | Not tested |

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
describe "#to_c" do ... end                          # Group 2: untested, works
describe "#clone" do ... end                         # Group 2: untested, works
describe "Kernel conversions" do ... end             # Float(), Integer(), Rational()
describe "#magnitude" do ... end                     # Open issue 12 (should alias abs)
describe "#step" do ... end                          # Open issue 13
describe "raises by design" do ... end               # Group 4: angle, polar, step, magnitude
describe "#** with large exponents" do ... end       # version-gated: 3.3 vs 3.4+
describe "#abs2 with complex value" do ... end       # complex Unit(Complex(3,4),'m').abs2
describe "#angle/#polar for complex-valued units" do # open issue 14
```

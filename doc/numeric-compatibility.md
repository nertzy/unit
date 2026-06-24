# Numeric Compatibility Surface Area

This document surveys the full `Numeric` (and common Ruby number type) API surface
against `Unit`'s behaviour, identifying gaps in test coverage and actual bugs.

---

## How the inheritance works

`Unit < Numeric`. `Numeric` provides a large default implementation; `Unit`
overrides a focused subset. Everything else is inherited as-is, which means the
behaviour of each inherited method depends entirely on what `Numeric`'s
implementation does when it calls back into `Unit` — often `<=>`, `to_i`, or
`to_f`.

---

## Methods Unit explicitly overrides

These exist in `lib/unit/class.rb` and have at least some test coverage:

| Method | Notes |
|---|---|
| `*`, `/`, `+`, `-`, `**`, `-@` | Arithmetic — core, well-tested |
| `==`, `eql?`, `<=>` | Equality and ordering — well-tested, including edge cases |
| `abs` | Preserves unit |
| `zero?` | Delegates to `@value` |
| `round` | Preserves unit, accepts precision argument |
| `to_i`, `to_f` | Strip unit, return bare numeric |
| `coerce` | Enables Integer/Float on left-hand side |
| `dup`, `initialize_copy`, `freeze` | Immutability contract — tested |
| `inspect`, `to_s`, `to_tex` | Formatting |
| `approx` | Returns Float-valued unit |

---

## Inherited Numeric methods — behaviour inventory

### Group 1: Work correctly, currently untested

These behave sensibly through the inherited `Numeric` path and are worth adding
coverage for.

**`+@` (unary plus)**
```ruby
+Unit(3, 'm')   # => Unit("3 m")   — returns self via Numeric
```
No test. Trivial but worth a one-liner for completeness.

**`abs2`**
```ruby
Unit(3, 'm').abs2    # => Unit("9 m^2")
Unit(-3, 'm').abs2   # => Unit("9 m^2")
```
Implemented as `self * self.conj` in Numeric, which hits `Unit#*`. Returns a
dimensionally-correct result (`m²`). No test. Should verify the identity
`u.abs2 == u.abs ** 2`.

**`nonzero?`**
```ruby
Unit(0, 'm').nonzero?   # => nil
Unit(1, 'm').nonzero?   # => Unit("1 m")
```
Works correctly through `Numeric`. No test.

**`modulo` / `%`**
```ruby
Unit(7, 'm') % Unit(3, 'm')    # => Unit("1 m")
Unit(-7, 'm') % Unit(3, 'm')   # => Unit("2 m")   (always non-negative)
```
Works, preserves unit. No test. Incompatible units raise `IncompatibleUnitError`
(via the `<` comparison inside `Numeric#modulo`).

**`divmod`**
```ruby
Unit(7, 'm').divmod(Unit(2, 'm'))   # => [3, Unit("1 m")]
```
The integer quotient strips the unit (calls `to_i` internally); the remainder
preserves it. Works, no test.

**`between?` and `clamp`**
```ruby
Unit(1, 'm').between?(Unit(0, 'm'), Unit(2, 'm'))     # => true
Unit(5, 'm').clamp(Unit(0, 'm'), Unit(2, 'm'))         # => Unit("2 m")
Unit(-1, 'm').clamp(Unit(0, 'm'), Unit(2, 'm'))        # => Unit("0 m")
Unit(5, 'm').clamp(Unit(0, 'm')..Unit(2, 'm'))         # => Unit("2 m")  (Range form)
```
All route through `<=>` and work correctly. Incompatible dimensions raise
`ArgumentError` (existing `clamp` test in unit_spec covers this). Worth adding
positive cases to the "comparable" group and testing the Range form of `clamp`.

**`ceil`, `floor`, `truncate` (no-precision forms) — unit-stripping (see Bug §2)**
The no-arg forms return a bare `Integer` (unit stripped). This is consistent with
how `Integer` works — `2.ceil` returns `2` — but may surprise users. Document and
test that this is the defined behaviour.

**`ceil`, `floor`, `truncate` (with precision) — also unit-stripping**
```ruby
Unit(2.736, 'm').ceil(2)     # => 2.74      (Float, no unit)
Unit(2.736, 'm').floor(2)    # => 2.73      (Float, no unit)
Unit(2.736, 'm').truncate(2) # => 2.73      (Float, no unit)
```
Contrast with `round(2)` which preserves the unit. No tests for any
precision-argument variants of ceil/floor/truncate.

**`Kernel` conversions**
```ruby
Float(Unit(2.7, 'm'))    # => 2.7     (bare Float, no unit)
Integer(Unit(2, 'm'))    # => 2       (bare Integer)
Rational(Unit(2, 'm'))   # => (2/1)   (bare Rational)
```
These work via `to_f`/`to_i`/`to_r`-like paths and silently strip the unit.
No tests.

---

### Group 2: Bugs — wrong behaviour, no tests

These methods give incorrect or misleading results and need both a failing test
and a fix.

#### Bug 1: `#hash` violates the Ruby object-equality contract

Ruby requires: `a.eql?(b)` implies `a.hash == b.hash`.

```ruby
a = Unit(1, 'm')
b = Unit(1, 'm')
a.eql?(b)          # => true
a.hash == b.hash   # => false  ← CONTRACT VIOLATED
```

**Consequence:** `Unit` objects are silently broken as Hash keys and Set members.

```ruby
h = { Unit(1, 'm') => 'one meter' }
h[Unit(1, 'm')]    # => nil   ← key lookup always misses
```

`Unit` needs to define `#hash` based on `[value, unit]` (the same fields
`eql?` inspects). Suggested fix:

```ruby
def hash
  [value, unit].hash
end
```

#### Bug 2: `#ceil`, `#floor`, `#truncate` strip the unit but `#round` does not

`round` is explicitly overridden in `Unit` and preserves the unit. The other
three are inherited from `Numeric` (which calls `to_i`/`to_f` internally) and
silently return a bare numeric.

```ruby
Unit(2.7, 'm').round    # => Unit("3 m")   ✓ preserves unit
Unit(2.7, 'm').ceil     # => 3             ✗ strips unit
Unit(2.7, 'm').floor    # => 2             ✗ strips unit
Unit(2.7, 'm').truncate # => 2             ✗ strips unit
```

Same asymmetry with a precision argument:

```ruby
Unit(2.736, 'm').round(2)    # => Unit("2.74 m")   ✓
Unit(2.736, 'm').ceil(2)     # => 2.74              ✗
Unit(2.736, 'm').floor(2)    # => 2.73              ✗
Unit(2.736, 'm').truncate(2) # => 2.73              ✗
```

These should be overridden analogously to `round`.

#### Bug 3: `#finite?` and `#infinite?` ignore the value

`Numeric#infinite?` is hardcoded to return `nil` (only `Float` overrides it).
`Numeric#finite?` returns `true` unless `infinite?` is truthy. Since `Unit` does
not override either, a `Unit` wrapping `Float::INFINITY` reports itself as finite:

```ruby
Unit(Float::INFINITY, 'm').infinite?  # => nil    ✗ (expected 1)
Unit(Float::INFINITY, 'm').finite?    # => true   ✗ (expected false)
```

These should delegate to `@value`:

```ruby
def infinite?
  value.respond_to?(:infinite?) ? value.infinite? : nil
end

def finite?
  value.respond_to?(:finite?) ? value.finite? : true
end
```

#### Bug 4: `#positive?` and `#negative?` raise on dimensional units

`Numeric#positive?` and `negative?` call `self > 0` / `self < 0`, which routes
through `<=>`, which raises `ArgumentError` when comparing a dimensional unit
with an `Integer`:

```ruby
Unit(3, 'm').positive?   # => ArgumentError: comparison of Unit("3 m") with Integer failed
Unit(-3, 'm').negative?  # => ArgumentError: comparison of Unit("3 m") with Integer failed
```

`respond_to?(:positive?)` returns `true`, so callers get a surprise. These
should be overridden to compare `value` directly:

```ruby
def positive?
  value > 0
end

def negative?
  value < 0
end
```

Dimensionless units already work correctly (since `<=>` against `Integer` succeeds
when there's no dimension mismatch).

#### Bug 5: `#numerator` and `#denominator` raise despite `respond_to?` returning `true`

`Numeric#numerator` and `#denominator` are defined and call `to_r` internally.
`Unit` does not define `to_r`, so they raise at runtime:

```ruby
Unit(1, 'm').respond_to?(:numerator)   # => true
Unit(1, 'm').numerator                 # => NoMethodError: undefined method 'to_r'
```

Options: define `to_r` (raises `TypeError` for dimensional units, delegates to
`value.to_r` for dimensionless), or override `numerator`/`denominator`
similarly.

#### Bug 6: `#remainder` raises on dimensional units

`Numeric#remainder` is implemented as:
```ruby
def remainder(y)
  x = self
  x - (x / y).truncate * y   # calls truncate then <=>
end
```
The `truncate` call returns a bare integer (Bug 2), and then the subsequent `*`
and `-` operations collapse. In practice it raises `ArgumentError` because
the intermediate `truncate` comparison path breaks on dimensional units.

```ruby
Unit(7, 'm').remainder(Unit(3, 'm'))    # => ArgumentError
Unit(-7, 'm').remainder(Unit(3, 'm'))   # => ArgumentError
```

This would be fixed as a side effect of fixing `ceil`/`floor`/`truncate` (Bug 2).

#### Bug 7: `Numeric#div` silently loses unit on incompatible operands

`Numeric#div` is `(self / other).floor` (calls `to_i` on the result). For
compatible units the result is dimensionless, so the loss is expected. For
incompatible units, `Unit#/` still produces a valid `m/s` unit, then `to_i`
strips it silently:

```ruby
Unit(7, 'm').div(Unit(2, 's'))   # => 3  (no unit, no error)
```

Whether this is a bug or intentional depends on the semantics you want for `div`.
At minimum it should be tested so the current behaviour is explicit.

---

### Group 3: Methods that raise by design (document-only)

These raise for dimensional units in a principled way and should have tests
confirming the error:

| Method | Behaviour |
|---|---|
| `angle` / `arg` / `phase` | `ArgumentError` (dimensional `<=>` 0 fails) |
| `magnitude` | `ArgumentError` (same — unlike `abs` which is overridden) |
| `polar` | `ArgumentError` (calls `abs` which works, but then `arg` which fails) |
| `step` | `ArgumentError` (compares step value with Integer internally) |
| `**` with a `Unit` exponent | `TypeError` (explicit guard in `Unit#**`) — tested |
| `+`, `-` with incompatible units | `IncompatibleUnitError` — tested |

Note the asymmetry: `abs` is overridden and works; `magnitude` is inherited and
raises. They should behave the same.

---

### Group 4: Inherited methods that work fine but deserve explicit tests

| Method | Current behaviour | Missing test? |
|---|---|---|
| `integer?` | Always `false` (Unit is never an Integer) | Yes |
| `real?` | Always `true` | Yes |
| `real` | Returns `self` | Yes |
| `imag` / `imaginary` | Returns `0` | Yes |
| `conj` / `conjugate` | Returns `self` | Yes |
| `rect` / `rectangular` | Returns `[self, 0]` | Yes |
| `to_c` | Returns `(Unit("3 m")+0i)` | Yes |
| `to_int` | Strips unit, returns Integer (same as `to_i`) | Yes |
| `clone` | Returns `self` (Numeric immutability — same as `dup`) | Yes |
| `fdiv` with scalar | `Unit(7, 'm').fdiv(2) => 3.5` (Float, no unit) | Yes |
| `fdiv` with unit | `Unit(7, 'm').fdiv(Unit(2, 'm')) => Unit("3.5 m^-1")` | Yes |

---

## Summary of bugs (severity order)

| # | Method(s) | Severity | Fix |
|---|---|---|---|
| 1 | `hash` | **Critical** — broken Hash/Set membership | Define `hash` from `[value, unit]` |
| 2 | `ceil`, `floor`, `truncate` | **High** — inconsistent with `round` | Override, preserve unit |
| 3 | `finite?`, `infinite?` | **High** — wrong answers for Infinity values | Override, delegate to `@value` |
| 4 | `positive?`, `negative?` | **Medium** — raises instead of answering | Override, compare `value` |
| 5 | `numerator`, `denominator` | **Medium** — `respond_to?` lies | Define `to_r` or override both |
| 6 | `remainder` | **Medium** — raises (consequence of Bug 2) | Fixed by Bug 2 fix |
| 7 | `div` with incompatible units | **Low** — silent unit loss | Add test, decide on semantics |
| 8 | `round(half:)` | **Medium** — raises `TypeError` on all versions | Update signature to accept `**opts` |

---

## Ruby version compatibility (3.3 / 3.4 / 4.0)

The CI matrix covers Ruby 3.3, 3.4, 4.0, and `head`. The `Numeric`, `Float`,
`Integer`, `Rational`, and `Comparable` method sets are **identical** across
all three versions — no methods were added or removed between 3.3 and 4.0.

However, there are three **behavioural changes** that affect `Unit`.

### 1. `Integer#**` / `Rational#**` overflow changed in Ruby 3.4

**Ruby 3.3:** raising an integer to a very large power silently overflowed to
`Float::INFINITY`, emitting a warning at `$VERBOSE` level.

**Ruby 3.4+:** the result stays an `Integer` (an arbitrary-precision bignum);
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

Any test asserting that very-large-exponent `Unit#**` produces `Infinity` would
pass on 3.3 and fail on 3.4+. Conversely, tests checking the bignum path would
fail on 3.3. **Version-gate** such tests, or confine them to Float-valued units
(`Unit(2.0, 'm') ** 100_000_000` still yields `Infinity` on all versions because
it goes through `Float#**`).

Note: `Rational#**` follows the same rule — extremely large `Rational` values
that previously returned `Float::NAN` or `Float::INFINITY` now return a
(potentially huge) `Rational` on 3.4+.

### 2. `Kernel#Float()` is more permissive in Ruby 3.4

**Ruby 3.3:** `Float("1.")` and `Float("1.E-1")` raise `ArgumentError`.

**Ruby 3.4+:** both are accepted.

```ruby
Float("1.")    # 3.3: ArgumentError;  3.4+: 1.0
Float("1.E-1") # 3.3: ArgumentError;  3.4+: 0.1
```

`Unit` does not call `Kernel#Float()` internally and does not expose a
string-based constructor that routes through it, so this change has **no direct
impact on `Unit`**. It can affect code that builds a `Unit` from a user-supplied
string like `Unit("1. m")` if parsing uses `Float()` under the hood — worth
verifying in the parser tests.

### 3. `Unit#round(half:)` does not accept the keyword argument (all versions)

Ruby's `Numeric#round` has accepted `half: :up/:down/:even` since Ruby 3.x.
`Unit#round` overrides this but only accepts a positional `ndigits` argument,
so the keyword form raises on all supported versions:

```ruby
Unit(2.5, 'm').round(half: :up)
# => TypeError: no implicit conversion of Hash into Integer  (3.3 / 3.4 / 4.0)
```

This is a **pre-existing bug on all three versions** rather than a
version-specific regression. The fix is to update `Unit#round`'s signature to
match `Numeric#round`:

```ruby
def round(digits = 0, **opts)
  Unit.new(value.round(digits, **opts), unit)
end
```

### Version compatibility summary

| Area | 3.3 | 3.4 | 4.0 | Notes |
|---|---|---|---|---|
| `Numeric` method set | identical | identical | identical | no additions or removals |
| `Integer#**` overflow | → `Float::INFINITY` + warning | → bignum `Integer` | → bignum `Integer` | affects `Unit#**` with Integer value |
| `Rational#**` overflow | → `Float::NAN` / `Float::INFINITY` | → large `Rational` | → large `Rational` | affects `Unit#**` with Rational value |
| `Float#**` overflow | → `Float::INFINITY` | → `Float::INFINITY` | → `Float::INFINITY` | **unchanged** — Float overflow behaviour not changed |
| `Kernel#Float("1.")` | `ArgumentError` | `1.0` | `1.0` | no internal Unit impact |
| `Unit#round(half:)` | `TypeError` | `TypeError` | `TypeError` | bug on all versions |
| All other `Numeric` inherited behaviours | identical | identical | identical | |

---

## Suggested new test groups

```
describe "#hash" do ... end                 # Bug 1: hash contract
describe "#ceil / #floor / #truncate" do    # Bug 2: unit preservation
describe "#finite? / #infinite?" do         # Bug 3: float edge values
describe "#positive? / #negative?" do       # Bug 4
describe "#numerator / #denominator" do     # Bug 5
describe "#remainder" do                    # Bug 6 (after ceil/floor fix)
describe "#abs2" do ... end                 # Group 1: correct, untested
describe "#nonzero?" do ... end             # Group 1
describe "#modulo / %" do ... end           # Group 1 (with incompatible-unit case)
describe "#divmod" do ... end               # Group 1
describe "#between? / #clamp" do ... end    # Group 1 positive cases + Range form
describe "#integer? / #real? / #real" do    # Group 4
describe "#conj / #rect / #imag" do         # Group 4
describe "#to_int / #to_c" do ... end       # Group 4
describe "#fdiv" do ... end                 # Group 4
describe "methods that raise by design" do  # Group 3: angle, magnitude, step, polar
describe "#round with half: keyword" do    # Bug 8: TypeError on half: arg
describe "#** with large exponents" do     # version-gated: 3.3 Float::INFINITY vs 3.4+ bignum
```

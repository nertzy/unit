README
===
**Unit** introduces computational units to Ruby. It offers built-in support for binary, mathematical, SI, imperial, scientific and temporal units, and a simple interface for adding your own, custom units.

[![Gem Version](https://img.shields.io/gem/v/unit.svg)](https://rubygems.org/gems/unit) [![CI](https://github.com/minad/unit/actions/workflows/ci.yml/badge.svg)](https://github.com/minad/unit/actions/workflows/ci.yml)

- Define units for operands to avoid the inevitable mistakes that plague unit-less operations.
- Perform complex mathematical operations while respecting the units of each operand.
- Get meaningful errors when units aren't compatible.
- Convert values between different systems of units with ease.

Examples
===
### General Usage

    require 'unit'
    puts 1.meter.in_kilometer
    puts 1.MeV.in_joule
    puts 10.KiB / 1.second
    puts 10.KiB_per_second
    puts Unit('1 m/s^2')

### Mathematics

    Unit(1, 'km') + Unit(500, 'm') == Unit(1.5, 'km')
    Unit(1, 'kg') - Unit(500, 'g') == Unit(0.5, 'kg')
    Unit(100, 'miles/hour') * Unit(0.5, 'hours') == Unit('50 mi')
    Unit(5.5, 'feet') / 2 == Unit(2.75, 'feet')
    Unit(2, 'm') ** 2 == Unit(4, 'm^2')

### Complex-valued units

Units with complex values are supported for domains such as electrical
impedance and signal processing:

    z = Unit(Complex(3, 4), 'ohm')   # 3+4i Ω
    z.abs                            # => Unit("5.0 Ω")  (magnitude)
    z.real                           # => Unit("3 Ω")
    z.imag                           # => Unit("4 Ω")
    z.conj                           # => Unit("3-4i Ω")
    z.real?                          # => false

### Conversions

    Unit(1, 'mile').in('km') == Unit(1.609344,  'km')
    (Unit(10, 'A') * Unit(0.1, 'volt')).in('watts') == Unit(1, 'watt')

See the test cases for many more examples.

Maintainers
---
Daniel Mendler and [Chris Cashwell](https://github.com/ccashwell)


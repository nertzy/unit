# call-seq:
#   Unit(value = 1, unit = '', system = Unit.default_system) -> unit
#   Unit(value = 1, unit = '', system = Unit.default_system, exception: true) -> unit or nil
#
# Constructs a +Unit+ from a value and a unit expression.
#
#   Unit(1, 'm')          # => Unit("1 m")
#   Unit(9.8, 'm/s^2')    # => Unit("9.8 m/s²")
#   Unit(1, 2, 'm')       # => Unit("1/2 m")    (Rational value)
#
# With <tt>exception: false</tt>, returns +nil+ instead of raising when
# the unit string is unknown or malformed — following the same convention
# as +Integer(str, exception: false)+ and +Float(str, exception: false)+:
#
#   Unit('flarb', exception: false)        # => nil  (unknown unit)
#   Unit(1, 'm)', exception: false)        # => nil  (malformed)
#   Unit(3.5, 'm/s', exception: false)     # => Unit("3.5 m/s")
def Unit(*args, exception: true)
  value = Numeric === args.first ? args.shift : 1
  value = Rational(value, args.shift) if Numeric === args.first

  system = args.index {|x| Unit::System === x }
  system = system ? args.delete_at(system) : Unit.default_system

  unit = args.index {|x| String === x }
  unit = system.parse_unit(args.delete_at(unit)) if unit

  unless unit
    unit = args.index {|x| Array === x }
    unit = args.delete_at(unit) if unit
  end

  unit ||= []
  system.validate_unit(unit)

  raise ArgumentError, 'wrong number of arguments' unless args.empty?

  Unit.new(value, unit, system)
rescue TypeError, Unit::ParseError
  raise unless exception == false
  nil
end

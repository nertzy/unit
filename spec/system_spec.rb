# -*- coding: utf-8 -*-
require 'spec_helper'

describe Unit::System do
  let(:system) { Unit::System.new("test") }

  describe "#load" do
    it "should load an IO object" do
      system.load(:si)
      test_file = File.join(File.dirname(__FILE__), "yml", "io.yml")
      File.open(test_file) { |file| system.load(file) }
      expect(Unit(1, "pim", system)).to eq(Unit(3.14159, "m", system))
    end

    context "when passed a String" do
      context "that is a filename" do
        it "should load the file" do
          filename = File.join(File.dirname(__FILE__), "yml", "filename.yml")
          system.load(:si)
          system.load(filename)
          expect(Unit(2, "dzm", system)).to eq(Unit(24, "m", system))
        end
      end

      context "that is not a filename" do
        it "should load the built-in system of that name" do
          system.load("si")
          expect { Unit(2, 'm', system) }.not_to raise_exception
        end
      end
    end

    context "when passed a Hash" do
      context "of units" do
        it "should load the units" do
          system.load(:si)
          system.load(
            'units' => {
              'dozen_meter' => {
                'sym' => 'dzm',
                'def' => '12 m'
              }
            }
          )
          expect(Unit(2, "dzm", system)).to eq(Unit(24, "m", system))
        end
      end

      context "of factors" do
        it "should load the factors" do
          system.load(:si)
          system.load(
            'factors' => {
              'dozen' => {
                'sym' => 'dz',
                'def' => 12
              }
            }
          )
          expect(Unit(2, "dzm", system)).to eq(Unit(24, "m", system))
        end
      end

      context "when passed an invalid factor" do
        it "should raise an exception" do
          system.load(:si)
          expect {
            system.load(
              'factors' => {
                'dozen' => {
                  'sym' => 'dz'
                }
              }
            )
          }.to raise_exception("Invalid definition for factor dozen")
        end
      end
    end

    context "when called on the same filename a second time" do
      it "should be a no-op" do
        expect($stderr).not_to receive(:puts)
        test_file = File.join(File.dirname(__FILE__), "yml", "filename.yml")
        system.load(:si)
        system.load(test_file)
        expect { system.load(test_file) }.not_to raise_exception
      end
    end

    context "when called on the same symbol a second time" do
      it "should be a no-op" do
        expect($stderr).not_to receive(:puts)
        system.load(:si)
        expect { system.load(:si) }.not_to raise_exception
      end
    end
  end

  describe "lexing every symbol in the default system" do
    # Guards against the lexer silently dropping a registered glyph to a
    # dimensionless value (the historical Ω/% failure): every unit symbol the
    # system knows must parse back to that same unit. Built on a fresh system
    # with the documented default load-out so the set is deterministic and not
    # polluted by other specs loading optional systems onto Unit.default_system.
    default = Unit::System.new("default") do |sys|
      sys.load(:si)
      sys.load(:binary)
      sys.load(:degree)
      sys.load(:time)
    end
    default.unit_symbol.each do |sym, name|
      it "parses #{sym.inspect} as #{name}" do
        expect(Unit(1, sym, default).unit).to eq(Unit(1, name.to_s, default).unit)
      end
    end
  end

  describe "lexing a glyph symbol loaded at runtime" do
    # The lexer is derived from the registered symbols, so a unit defined after
    # the system was built (e.g. an app loading a domain unit) becomes lexable
    # without any change to the gem.
    it "parses a non-word glyph symbol once its unit is loaded" do
      system.load(:si)
      system.load('units' => { 'percent' => { 'sym' => '%', 'def' => '1 / 100' } })

      expect(Unit(1, '%', system).unit).to eq(Unit(1, 'percent', system).unit)
      expect(Unit(50, '%', system)).to eq(Unit(Rational(1, 2), system))
    end
  end

  describe "rejecting symbols it cannot resolve" do
    # The lexer matches any run of non-operator, non-whitespace characters as a
    # symbol — including glyphs that no system has registered — so an unknown
    # symbol reaches validation and fails loudly as "Undefined unit" instead of
    # being silently dropped to a dimensionless value. This keeps unknown
    # glyphs consistent with unknown ASCII symbols rather than special-casing
    # them into silence.
    before { system.load(:si) }

    it "raises for an unknown ASCII symbol" do
      expect { Unit(1, "foo", system) }.to raise_error(TypeError, "Undefined unit foo")
    end

    it "raises for an unregistered glyph instead of silently dropping it" do
      expect { Unit(1, "λ", system) }.to raise_error(TypeError, "Undefined unit λ")
      expect { Unit(5, "αβγ", system) }.to raise_error(TypeError, "Undefined unit αβγ")
    end

    it "raises when an unregistered glyph is implicitly multiplied with a known unit" do
      expect { Unit(1, "m λ", system) }.to raise_error(TypeError, "Undefined unit λ")
      expect { Unit(1, "λ m", system) }.to raise_error(TypeError, "Undefined unit λ")
    end

    it "names the unregistered glyph rather than a neighboring operator" do
      # The glyph used to be dropped, leaving a dangling operator that raised a
      # misleading "Unexpected token /"; now the real culprit is reported.
      expect { Unit(1, "m/λ", system) }.to raise_error(TypeError, "Undefined unit λ")
      expect { Unit(1, "λ^2", system) }.to raise_error(TypeError, "Undefined unit λ")
    end
  end

  describe "parsing a unit whose system has not been loaded" do
    # Directly answers "what happens with unit strings that aren't loaded": the
    # symbol is lexed but unresolved, so it fails loudly until the defining
    # system is loaded, after which it resolves normally.
    it "raises until the defining system is loaded, then resolves" do
      system.load(:si)
      # megaelectronvolt is defined in :scientific, which is not loaded yet.
      expect { Unit(1, "MeV", system) }.to raise_error(TypeError, "Undefined unit MeV")

      system.load(:scientific)
      expect(Unit(1, "MeV", system).unit).to eq(Unit(1, "megaelectronvolt", system).unit)
    end
  end

  describe "#parse_unit with an empty or whitespace-only expression" do
    before { system.load(:si) }

    it "returns [] (the dimensionless unit) for an empty string" do
      expect(system.parse_unit("")).to eq([])
    end

    it "returns [] (the dimensionless unit) for a whitespace-only string" do
      expect(system.parse_unit("  ")).to eq([])
    end
  end
end

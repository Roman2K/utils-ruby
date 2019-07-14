require 'bigdecimal'
require 'bigdecimal/util'

module Utils

module Fmt
  def self.duration(d)
    case
    when d < 60 then "%ds" % d
    when d < 3600 then m, d = d.divmod(60); "%dm%s" % [m, duration(d)]
    when d < 86400 then h, d = d.divmod(3600); "%dh%s" % [h, duration(d)]
    else ds, d = d.divmod(86400); "%dd%s" % [ds, duration(d)]
    end.sub /([a-z])(0[a-z])+$/, '\1'
  end

  def self.d(d, *args, &block)
    dec(d).to_s *args, &block
  end

  def self.dec(*args, &block)
    DecFmt.new *args, &block
  end

  def self.pct(d, *args, &block)
    d = d.to_d * 100
    "%s%%" % [dec(d).to_s(*args, &block)]
  end

  class DecFmt
    def initialize(d)
      @s = d.to_d.to_s("F").freeze
    end

    def prec
      i = @s.index(".") or raise "decimal separator not found"
      @s.size - (i+1)
    end

    def to_s(prec=-1, z: true)
      cur = self.prec
      case
      when prec < 0 || prec == cur
        @s.dup
      when prec == 0
        @s[0 .. -cur - 2]
      when prec < cur
        DecFmt.new(BigDecimal(@s).round(prec)).to_s prec
      else
        @s.ljust(@s.size + (prec - cur), "0")
      end.tap do |s|
        s.sub! /\.?0+$/, "" if !z
      end
    end
  end

  class NumFmt
    def initialize(multiple, units)
      @multiple = multiple
      @units = units
    end

    def format(n, prec=0)
      n = BigDecimal n.to_s unless n.kind_of? BigDecimal
      @units.each.with_index do |name, index|
        in_unit = n / @multiple ** index
        next if in_unit >= @multiple && index < @units.size - 1
        prec = 0 if index == 0
        n = in_unit
        n = n.round prec if prec >= 0
        n = DecFmt.new(n).to_s prec
        return "#{n}#{name}"
      end
    end
  end

  SIZE_FMT = NumFmt.new 1024, %w( B KiB MiB GiB TiB )
  def self.size(n, prec=1); SIZE_FMT.format n, prec end
end

end

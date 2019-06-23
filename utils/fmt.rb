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

    def to_s(prec=-1)
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
      end
    end
  end
end

end

require 'yaml'

module Utils

class Conf
  def initialize(x, path: [])
    @path = path
    @h =
      case x
      when Pathname then x.open('r') { |f| YAML.load f }
      when String then File.open(x, 'r') { |f| YAML.load f }
      when Hash then x
      else raise TypeError, "unhandled config object"
      end
  end

  def [](key)
    key.to_s.split(".").inject(self) { |c,k| c.at k }
  end

  def lookup(key)
    self[key]
  rescue KeyError
  end

  protected def at(key)
    val = @h.fetch key do
      @h.fetch(Symbol === key ? key.to_s : key.to_sym) do
        raise KeyError, "missing key: #{path_for key}"
      end
    end
    case val
    when Hash then self.class.new val, path: @path + [key]
    when String then expand_tilde val
    else val
    end
  end

  private def path_for(key)
    [*@path, key].join "."
  end

  def self.home; ENV.fetch "HOME" end

  private def expand_tilde(path)
    case path
    when %r{\A~(/.*|\z)} then self.class.home + $1
    when %r{\A~([^~].*)} then "#{self.class.home}/#{$1}"
    else path
    end
  end
end

end

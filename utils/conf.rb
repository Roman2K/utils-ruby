require 'yaml'

module Utils

class Conf
  def initialize(val, path: [], load_path: [])
    val = Pathname val if String === val

    @path, @load_path = path, load_path.map { |p| Pathname p }

    if Pathname === val
      file = resolve_path val
      @load_path = [file.dirname] | @load_path
      val = file.open('r') { |f| YAML.load f }
    end
    unless Hash === val
      raise InvalidTypeError.new(val)
    end

    @h = val
  end

  class InvalidTypeError < StandardError
    def initialize(val)
      @val = val
    end

    attr_reader :val

    def to_s
      "invalid type: %s" % [val.class]
    end
  end

  def [](key)
    key.to_s.split(".").inject(self) { |c,k| c.at k }
  end

  def delete(key)
    raise "dot keys not supported" if key =~ /\./
    res = self[key]
    [key.to_s, key.to_sym].each { |k| @h.delete k }
    res
  end

  def slice(*keys)
    keys.each_with_object({}) { |k,h| h[k] = self[k] }
  end

  def values_at(*keys)
    keys.map { |k| self[k] }
  end

  def to_hash
    keys.inject({}) { |h,k| h[k] = self[k]; h }
  end

  def lookup(key)
    self[key]
  rescue KeyError
  end

  protected def at(key)
    val = @h.fetch key do
      @h.fetch Symbol === key ? key.to_s : key.to_sym do
        raise KeyError, "missing key: #{path_for key}"
      end
    end

    config_val = -> val do
      self.class.new val, path: @path + [key]
    end
    coerce_val = -> val do
      case val
      when Hash then config_val[val]
      when Array then val.map &coerce_val
      when String then string_val val
      else val
      end
    end

    val = coerce_val[val]
    if self.class === val && val.keys == %i[include]
      val = begin
        config_val[resolve_path(Pathname(string_val val[:include]))]
      rescue InvalidTypeError
        coerce_val[$!.val]
      end
    end

    val
  end

  protected def keys
    @h.keys.map &:to_sym
  end

  private def path_for(key)
    [*@path, key].join "."
  end

  private def string_val(val)
    Utils.expand_tilde val
  end

  def resolve_path(path)
    return path if path.ascend.inject { |_, name| name }.to_s != "."
    *from_path, last = @load_path.map { |dir| dir.join path }
    from_path.find(&:file?) || last || path
  end
end

end

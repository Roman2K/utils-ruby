require 'yaml'

module Utils

class YAMLTmpl
  def initialize(filters=MAIN_FILTERS)
    @filters = Filters[filters]
  end

  class Filters < Hash
    def self.[](fs); super fs.transform_keys &:to_s end
  end

  def result(obj)
    filters = {}.then do |vars|
      @filters.
        merge(Filters[_get: GetVar.new(vars)]) { |k,a,b| b.with_defaults a }.
        merge(Filters[_vars: SetVars.new(vars)])
    end
    tmpl = self.class.new filters

    case obj
    when Array
      obj.map { tmpl.result _1 }
    when Hash
      filters.slice(*obj.keys).
        map { |k,f| [f, obj.delete(k)] }.
        each { |f, param|
          # pp f: f, obj: obj, param: param
          obj = call_apply(f, obj, tmpl.result(param)) do |opts|
            tmpl.result opts
          end
        }
      case obj
      when Hash then obj.transform_values { tmpl.result _1 }
      else tmpl.result obj
      end
    else
      obj
    end
  end

  private def call_apply(f, h, param)
    if f.public_method(:apply).parameters.drop(1).all? { |t,| t =~ /^key/ }
      f.apply param, **yield(h).transform_keys(&:to_sym)
    else
      f.apply h, param
    end
  end

  module Incl
    def self.apply(h, path)
      YAML.load_file path
    end
  end

  class GetVar
    def initialize(vars, defaults: nil)
      @vars = vars
      @defaults = defaults
    end

    def inspect
      "GetVar #{@vars.inspect}".tap do |s|
        s << " -> #{@defaults.inspect}" if @defaults
      end
    end

    def with_defaults(vars)
      self.class.new @vars, defaults: vars
    end

    def apply(name, default: nil)
      @vars.fetch name do
        if @defaults
          @defaults.apply name, default: default
        else
          default or raise "missing var: #{name.inspect}"
        end
      end
    end
  end

  class SetVars
    def initialize(vars); @vars = vars end
    def apply(obj, values); @vars.update values; obj end
  end

  module Merge
    def self.apply(dst, src)
      dst.merge src do |k, old, new|
        case [old, new]
        in [Hash, Hash] then apply old, new
        in [Array, Array] then old + new
        else new
        end
      end
    end
  end

  module Eval
    def self.apply(str, vars:)
      eval str, vars_binding(vars)
    end

    def self.vars_binding(vars)
      eval("lambda { |#{vars.keys.join ", "}| binding }").call *vars.values
    end
  end

  module Noop
    def self.apply(h); h end
  end

  MAIN_FILTERS = {
    _incl: Incl,
    _eval: Eval,
    _merge: Merge,
    _noop: Noop,
  }
end

end

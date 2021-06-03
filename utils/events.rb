module Utils

class Events
  def initialize
    @cbs = {}
  end

  def events; @cbs.keys end
  def cb_count(ev, key=nil); get_cbs(ev).fetch(key) { return 0 }.size end
  def on(*args, **opts, &block); reg_on *args, **opts, &block; self end

  def reg_on(ev, key=nil, replace: !!key, once: false, &cb)
    cbs = get_keyed_cbs ev, key
    cbs.clear if replace
    cb = Callback.new block: cb, once: once
    cbs << cb
    Registration.new ev, key, cb
  end

  Callback = Struct.new :block, :once, :fired, keyword_init: true
  Registration = Struct.new :ev, :key, :cb

  private def get_cbs(ev)
    @cbs.fetch(ev) { raise "unknown event: %p" % [ev] }
  end

  private def get_keyed_cbs(ev, key)
    reg = get_cbs ev
    reg[key] ||= []
  end

  def declare(*evs)
    evs.each do |ev|
      raise "already declared: %p" % [ev] if @cbs.key? ev
      @cbs[ev] = {}
    end
    self
  end

  def emit(ev, *args)
    get_cbs(ev).each_value do |cbs|
      cbs.delete_if do |cb|
        cb.block.call *args
        cb.fired = true
        cb.once
      end
    end
    self
  end
  alias fire emit

  def unregister(reg)
    cbs = get_keyed_cbs reg.ev, reg.key
    if !cbs.delete(reg.cb)
      raise InvalidRegError unless reg.cb.once && reg.cb.fired
    end
    reg.cb.fired = false
    self
  end

  class InvalidRegError < StandardError; end
end

end

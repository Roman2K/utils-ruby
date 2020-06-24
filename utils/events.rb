module Utils

class Events
  def initialize
    @cbs = {}
  end

  def events; @cbs.keys end
  def cb_count(ev, key=nil); get_cbs(ev).fetch(key) { return 0 }.size end

  def on(ev, key=nil, replace: !!key, once: false, &cb)
    reg = get_cbs(ev)
    cbs = reg[key] ||= []
    cbs.clear if replace
    cbs << Callback.new(block: cb, once: once)
    self
  end

  Callback = Struct.new :block, :once, keyword_init: true

  private def get_cbs(ev)
    @cbs.fetch(ev) { raise "unknown event: %p" % [ev] }
  end

  def declare(*evs)
    evs.each do |ev|
      raise "already declared: %p" % [ev] if @cbs.key? ev
      @cbs[ev] = {}
    end
    self
  end

  def fire(ev, *args)
    get_cbs(ev).each_value do |cbs|
      cbs.delete_if do |cb|
        cb.block.call *args
        cb.once
      end
    end
    self
  end
end

end

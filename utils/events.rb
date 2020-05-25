module Utils

class Events
  def initialize
    @cbs = {}
  end

  def on(ev, key=nil, replace: !!key, &cb)
    reg = get_cbs(ev)
    cbs = (reg[key] ||= [])
    cbs.clear if replace
    cbs << cb
    self
  end

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
      cbs.each do |cb|
        cb.call *args
      end
    end
    self
  end
end

end

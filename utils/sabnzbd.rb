module Utils

class SABnzbd
  def initialize(uri, log:)
    uri = Utils.merge_uri uri, output: "json"
    @http = SimpleHTTP.new uri, log: log
    @http.type_config.update json_in: false, json_out: true
  end

  def history &block; get_slots({mode: "history"}, "history", &block) end
  def restart; @http.get [mode: "restart"] end
  def queue_raw; @http.get([mode: "queue"]).fetch("queue") end
  def queue &block; get_slots({mode: "queue"}, "queue", &block) end
  def queue_resume_all; @http.get [mode: "resume"] end

  def queue_pause(nzoid)
    @http.get [mode: "queue", name: "pause", value: nzoid]
  end

  def queue_resume(nzoid)
    @http.get [mode: "queue", name: "resume", value: nzoid]
  end

  LIMIT = 500

  private def get_slots(params, key, &block)
    return enum_for __method__, params, key unless block
    start = 0
    last_nzoid = nil
    loop do
      items = @http.get([params.merge(start: start, limit: LIMIT)]).
        fetch(key).
        fetch("slots")
      if last_nzoid
        idx = items.find_index { |i| i.fetch("nzo_id") == last_nzoid } \
          or raise "slots moved too much since last iteration"
        start += idx
        items.slice! 0..idx
      end
      break if items.empty?
      items.each &block
      start += items.size - 1
      last_nzoid = items.fetch(-1).fetch "nzo_id"
    end
  end
end

end

module Utils

# https://github.com/transmission/transmission/blob/master/extras/rpc-spec.txt
class Transmission
  def initialize(uri, log:)
    uri = Utils.merge_uri uri, "/transmission/rpc"
    @http = Utils::SimpleHTTP.new uri, json: true, log: log
  end

  def torrents
    req("torrent-get", fields: Torrent::API_FIELDS).
      fetch("torrents").
      map { Torrent.new _1 }
  end

  def default_dir_free
    key = "download-dir"
    path = req("session-get", fields: [key]).fetch key
    req("free-space", path: path).fetch "size-bytes"
  end

  def delete_perm(ids)
    req "torrent-remove", ids: ids, "delete-local-data" => true
  end

  def set_speed_limits(up:, down:)
    args = {}
    %i[up down].each do |var|
      args["speed-limit-#{var}-enabled"] = true
      args["speed-limit-#{var}"] = eval(var.to_s)
    end
    req "session-set", args
  end

  private def req(method, arguments)
    @sess_id ||= @http.get("", expect: [Net::HTTPConflict], json: false).
      []('X-Transmission-Session-Id') \
      or raise "missing session ID"
    res = @http.post("", {method: method, arguments: arguments},
      expect: [Net::HTTPOK]
    ) do |req|
      req['X-Transmission-Session-Id'] = @sess_id
    end
    res.fetch("result").then do |s|
      s == "success" or raise "unexpected result: #{s}"
    end
    res.fetch "arguments"
  end

  class Torrent
    STATUSES = {
      0 => :stopped,
      1 => :check_wait,
      2 => :check,
      3 => :download_wait,
      4 => :download,
      5 => :seed_wait,
      6 => :seed,
    }.freeze

    API_FIELDS = %w[
      hashString name downloadDir sizeWhenDone status addedDate doneDate percentDone
      uploadRatio desiredAvailable
    ]

    def initialize(data); @data = data end
    def name; @data.fetch "name" end
    def cat; File.basename @data.fetch("downloadDir") end
    def hash_string; @data.fetch "hashString" end
    def size; @data.fetch "sizeWhenDone" end
    def state; STATUSES.fetch @data.fetch "status" end
    def added_on; Time.at @data.fetch "addedDate" end
    def completion_on; Time.at @data.fetch "doneDate" end
    def progress; @data.fetch "percentDone" end
    def ratio; @data.fetch "uploadRatio" end
  end
end

end

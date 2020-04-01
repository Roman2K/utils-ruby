require 'net/http'
require 'json'

module Utils

class QBitTorrent
  def initialize(uri, log: Log.new)
    @log = log
    user, password = uri.user, uri.password
    @uri = uri.dup.tap { |u| u.user = u.password = nil }.freeze
    set_cookie! user, password
  end

  def download_limit=(n)
    @log.debug "setting download limit to: %d bytes" % n
    post! "/command/setGlobalDlLimit", 'limit' => n
  end

  def pause_downloading
    downloading.each { |t| pause t unless t.fetch("state") == "pausedDL" }
  end

  def resume_downloading
    downloading.each { |t| resume t if t.fetch("state") == "pausedDL" }
  end

  %i[all downloading completed paused active inactive].each do |filter|
    define_method filter do |*args, **opts, &block|
      torrents *args, filter: filter, **opts, &block
    end
  end

  def torrents(filter: nil)
    q = {filter: filter}
    uri = add_uri "/query/torrents", q.reject { |k,v| v.nil? }

    JSON.parse(get!(uri).body).tap do |ts|
      @log[q: q].debug "fetched %d torrents" % ts.size
    end
  end

  def torrent_files(t)
    JSON.parse get!("/query/propertiesFiles/#{t.fetch "hash"}").body
  end

  def delete_perm(t)
    tlog(t).debug "deleting torrent (with data)"
    post! "/command/deletePerm", 'hashes' => t.fetch("hash")
  end

  private def tlog(t)
    @log[torrent: t.fetch("name")]
  end

  private def pause(t)
    tlog(t).debug "pausing torrent"
    post_hash! "/command/pause", t
  end

  private def resume(t)
    tlog(t).debug "resuming torrent"
    post_hash! "/command/resume", t
  end

  private def post_hash!(path, t)
    post! path, 'hash' => t.fetch("hash")
  end

  private def get!(path)
    request! new_req(:Get, path)
  end

  private def post!(path, data)
    req = new_req :Post, path
    req.form_data = data
    request! req
  end

  private def set_cookie!(user, password)
    req = new_req :Post, "/login"
    req.form_data = {'username' => user, 'password' => password}

    @cookie = request!(req)['set-cookie'].
      tap { |s| s or raise "failed login: %s" % res.body }.
      split(";", 2).
      fetch(0)
  end

  private def new_req(type, path, *args, &block)
    Net::HTTP.const_get(type).new(add_uri(path), *args, &block).tap do |req|
      req['Referer'] = @uri.to_s
      req['Cookie'] = @cookie
    end
  end

  private def add_uri(*args, &block)
    Utils.merge_uri @uri, *args, &block
  end

  private def request(*args, &block)
    Net::HTTP.
      start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https') do |http|
        http.request *args, &block
      end
  end

  private def request!(*args, &block)
    request(*args, &block).tap do |res|
      res.kind_of? Net::HTTPSuccess or raise "unexpected response: %p" % res
    end
  end
end

end # Utils

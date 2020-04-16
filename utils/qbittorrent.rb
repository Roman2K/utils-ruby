require 'net/http'
require 'json'

module Utils

# https://github.com/qbittorrent/qBittorrent/wiki/Web-API-Documentation
class QBitTorrent
  def initialize(uri, log: Log.new)
    @log = log
    user, password = uri.user, uri.password
    @uri = uri.dup.tap { |u| u.user = u.password = nil }.freeze
    set_cookie! user, password
  end

  def download_limit=(n)
    @log.info "setting download limit to: %d bytes" % n
    post! "/api/v2/transfer/setDownloadLimit", 'limit' => n
  end

  def pause_downloading
    pause downloading.select { |t| t.fetch("state") != "pausedDL" }
  end

  def resume_downloading
    resume downloading.select { |t| t.fetch("state") == "pausedDL" }
  end

  %i[all downloading completed paused active inactive].each do |filter|
    define_method filter do |*args, **opts, &block|
      torrents *args, filter: filter, **opts, &block
    end
  end

  def torrents(filter: nil)
    q = {filter: filter}
    uri = add_uri "/api/v2/torrents/info", q.reject { |k,v| v.nil? }

    JSON.parse(get!(uri).body).tap do |ts|
      @log[q: q].debug "fetched %d torrents" % ts.size
    end
  end

  def delete_perm(ts)
    post_hashes! "/api/v2/torrents/delete", ts, 'deleteFiles' => 'true' do |log|
      log.info "deleting (with data)"
    end
  end

  private def tlog(t)
    @log[torrent: t.fetch("name")]
  end

  private def pause(ts)
    post_hashes! "/api/v2/torrents/pause", ts do |log|
      log.info "pausing"
    end
  end

  private def resume(ts)
    post_hashes! "/api/v2/torrents/resume", ts do |log|
      log.info "resuming"
    end
  end

  private def get!(path)
    request! new_req(:Get, path)
  end

  private def post!(path, data)
    req = new_req :Post, path
    req.form_data = data
    request! req
  end

  private def post_hashes!(path, ts, data={})
    ts, log =
      if Array === ts
        [ts, @log[torrents: ts.size]]
      else
        [[ts], tlog(ts)]
      end
    if ts.empty?
      log[path: path].debug "no hashes to post"
      return
    end
    yield log if block_given?
    post! path, data.merge('hashes' => ts.map { |t| t.fetch "hash" } * "|")
  end

  private def set_cookie!(user, password)
    req = new_req :Post, "/api/v2/auth/login"
    req.form_data = {'username' => user, 'password' => password}

    @cookie = request!(req)['set-cookie'].
      tap { |s| s or raise "failed login" }.
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

  TIMEOUT = 20

  private def request(*args, &block)
    Utils.try_conn! TIMEOUT do
      Net::HTTP.
        start(@uri.host, @uri.port, use_ssl: @uri.scheme == 'https') do |http|
          http.request *args, &block
        end
    end
  end

  private def request!(*args, &block)
    request(*args, &block).tap do |res|
      res.kind_of? Net::HTTPSuccess or raise "unexpected response: %p" % res
    end
  end
end

end # Utils

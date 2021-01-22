require 'net/http'
require 'json'

module Utils

# https://github.com/qbittorrent/qBittorrent/wiki#webui-api
class QBitTorrent
  def initialize(uri, log: Log.new)
    @log = log
    user, password = uri.user, uri.password
    @uri = uri.dup.tap { |u| u.user = u.password = nil }.freeze
    set_cookie! user, password
  end

  def download_limit=(n)
    @log.debug "setting download limit to: %d bytes" % n
    post! "/api/v2/transfer/setDownloadLimit", 'limit' => n
  end

  def torrents(filter: nil)
    q = {filter: filter}
    uri = add_uri "/api/v2/torrents/info", q.reject { |k,v| v.nil? }
    get_json!(uri).
      tap { |ts| @log[q: q].debug "fetched %d torrents" % ts.size }.
      map { Torrent.new _1 }
  end

  class Torrent
    def initialize(data); @data = data end
    def name; @data.fetch "name" end
    def cat; @data.fetch "category" end
    def hash_string; @data.fetch "hash" end
    def size; @data.fetch "size" end
    def state; @data.fetch "state" end
    def added_on; Time.at @data.fetch "added_on" end
    def completion_on; Time.at @data.fetch "completion_on" end
    def progress; @data.fetch "progress" end
    def ratio; @data.fetch "ratio" end
    def downloading?
      case state
      when 'pausedDL' then false
      when 'downloading', /DL$/ then true
      else false
      end
    end
  end

  def recheck(ts)
    post_hashes! "/api/v2/torrents/recheck", ts do |log|
      log.debug "rechecking"
    end
  end

  def delete_perm(ts)
    post_hashes! "/api/v2/torrents/delete", ts, 'deleteFiles' => 'true' do |log|
      log.debug "deleting (with data)"
    end
  end

  private def tlog(t)
    @log[torrent: t.fetch("name")]
  end

  def pause(ts)
    post_hashes! "/api/v2/torrents/pause", ts do |log|
      log.debug "pausing"
    end
  end

  def resume(ts)
    post_hashes! "/api/v2/torrents/resume", ts do |log|
      log.debug "resuming"
    end
  end

  private def get!(path)
    request! new_req(:Get, path)
  end

  private def get_json!(uri)
    JSON.parse(get!(uri).body)
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
    post! path, data.merge('hashes' => ts.map(&:hash_string) * "|")
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

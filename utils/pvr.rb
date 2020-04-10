require 'net/http'
require 'json'

module Utils

module PVR
  class Basic
    DEFAULT_TIMEOUT = 60

    def initialize(uri, timeout: DEFAULT_TIMEOUT, log:)
      @http = SimpleHTTP.new uri, json: true, log: log
      @log = log
      @timeout = timeout
    end

    def history
      fetch_all(["/history", page: 1]).to_a
    end

    def commands
      @http.get "/command"
    end

    def downloaded_scan(path, download_client_id: nil, import_mode: nil)
      @http.post "/command", {}.tap { |body|
        body["name"] = self.class::CMD_DOWNLOADED_SCAN
        body["path"] = path
        body["downloadClientId"] = download_client_id if download_client_id
        body["importMode"] = import_mode if import_mode
      }
    end

    def command(id)
      @http.get "/command/#{id}"
    end

    def entity(id)
      @http.get "#{self.class::ENDPOINT_ENTITY}/#{id}"
    end

    protected def fetch_all(uri)
      return enum_for __method__, uri unless block_given?
      fetched = 0
      total = nil
      uri = uri.yield_self do |path, params={}|
        Utils.merge_uri path, pageSize: 200, **params
      end
      loop do
        Hash[URI.decode_www_form(uri.query || "")].
          slice("page", "pageSize").
          tap { |h| @log.debug "fetching %p of %s" % [h, uri] }
        data = @http.get uri
        total = data.fetch "totalRecords"
        page = data.fetch "page"
        if fetched <= 0 && page > 1
          fetched = data.fetch("pageSize") * (page - 1)
        end
        records = data.fetch "records"
        fetched += records.size
        @log.debug "fetch result: %p" \
          % {total: total, page: page, fetched: fetched, records: records.size}
        break if records.empty?
        records.each { |r| yield r }
        break if fetched >= total
        uri = Utils.merge_uri uri, page: page + 1
      end
    end
  end

  class Radarr < Basic
    CMD_DOWNLOADED_SCAN = "DownloadedMoviesScan"
    ENDPOINT_ENTITY = "/movie"
    def history_entity_id(ev); ev.fetch "movieId" end
  end

  class Sonarr < Basic
    CMD_DOWNLOADED_SCAN = "DownloadedEpisodesScan"
    ENDPOINT_ENTITY = "/episode"
    def history_entity_id(ev); ev.fetch "episodeId" end
  end
end # PVR

end # Utils

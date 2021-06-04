require 'net/http'
require 'json'

module Utils

module PVR
  class Basic
    DEFAULT_TIMEOUT = 60
    DEFAULT_BATCH_SIZE = 200

    def initialize(uri,
      batch_size: DEFAULT_BATCH_SIZE, timeout: DEFAULT_TIMEOUT, log: Log.new
    )
      @http = SimpleHTTP.new uri, json: true, timeout: timeout, log: log
      @log = log
      @batch_size = batch_size
    end

    def to_s; name.to_s end
    def name; self.class::NAME end
    def history_events; fetch_all(["/history", page: 1]) end
    def history; history_events.to_a end  # backwards compatibility
    def commands; @http.get "/command" end
    def command(id); @http.get "/command/#{id}" end
    def entity(id); @http.get "#{self.class::ENDPOINT_ENTITY}/#{id}" end
    def queue; fetch_all(["/queue", page: 1]).to_a end
    def check_health; post_command 'CheckHealth', {} end

    def downloaded_scan(path, download_client_id: nil, import_mode: nil)
      post_command self.class::CMD_DOWNLOADED_SCAN, {}.tap { |body|
        body["path"] = path
        body["downloadClientId"] = download_client_id if download_client_id
        body["importMode"] = CMD_IMPORT_MODES.fetch import_mode if import_mode
      }
    end

    CMD_IMPORT_MODES = {
      move: 'Move',
      copy: 'Copy',
    }

    private def post_command(name, body)
      @http.post "/command", body.merge("name" => name)
    end

    def queue_del(id, blacklist: nil)
      params = {}
      params[:blacklist] = "true" if blacklist
      @http.delete ["/queue/#{id}", params], nil
    end

    protected def group_key(ev, type, entity_id)
      [type, entity_id, ev.fetch("quality").fetch("quality").fetch("id")]
    end

    protected def fetch_all(uri)
      return enum_for __method__, uri unless block_given?
      fetched = 0
      total = nil
      uri = uri.yield_self do |path, params={}|
        Utils.merge_uri path, pageSize: @batch_size, **params
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
    NAME = "Radarr".freeze
    CMD_DOWNLOADED_SCAN = "DownloadedMoviesScan".freeze
    ENDPOINT_ENTITY = "/movie".freeze
    def history_entity(ev); ev.fetch 'movie' end
    def history_entity_id(ev); ev.fetch 'movieId' end
    def history_scannable_id(ev); history_entity_id ev end
    def history_dest_path(ev); ev.fetch('movie').fetch 'path' end
    def history_group_keys(ev); [history_group_key(ev)] end
    def history_group_key(ev); group_key ev, :movie, history_entity_id(ev) end
    def rescan(id); post_command 'RefreshMovie', 'movieIds' => [id] end
  end

  class Sonarr < Basic
    NAME = "Sonarr".freeze
    CMD_DOWNLOADED_SCAN = "DownloadedEpisodesScan".freeze
    ENDPOINT_ENTITY = "/episode".freeze
    KEY_EP_ID = 'episodeId'.freeze
    KEY_SERIES_ID = 'seriesId'.freeze
    def queue; @http.get "/queue" end
    def history_entity(ev); ev.fetch 'episode' end
    def history_entity_id(ev); ev.fetch KEY_EP_ID end
    def history_scannable_id(ev); ev.fetch KEY_SERIES_ID end
    def history_dest_path(ev); raise NotImplementedError end
    def history_group_keys(ev)
      [ history_group_key(ev),
        history_group_key(ev.dup.tap { _1.delete KEY_EP_ID }) ].uniq
    end
    def history_group_key(ev)
      group_key ev, *if id = ev[KEY_EP_ID]
        then [:episode, id]
        else [:series, ev.fetch(KEY_SERIES_ID)]
        end
    end
    def rescan(id); post_command 'RescanSeries', 'seriesId' => id end
  end

  class Lidarr < Basic
    NAME = "Lidarr".freeze
    def history_entity_id(ev); ev.fetch 'albumId' end
    def history_group_keys(ev); [history_group_key(ev)] end
    def history_group_key(ev); group_key ev, :album, history_entity_id(ev) end
  end

  module Event
    def self.of_pvr(pvr, ev)
      ev = ev.dup.extend(self)
      ev.instance_variable_set :@pvr, pvr
      ev
    end
      
    methods = PVR.constants.flat_map { |const|
      cls = PVR.const_get const
      next [] unless Class === cls && cls < Basic
      cls.public_instance_methods.grep(/^history_/) { $' }
    }.uniq.each { |method|
      define_method method do |*args, &block|
        @pvr.public_send :"history_#{method}", self, *args, &block
      end
    }
  end
end # PVR

end # Utils

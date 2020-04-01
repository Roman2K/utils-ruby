require 'net/http'
require 'json'

module Utils

module PVR
  class Basic
    DEFAULT_TIMEOUT = 20

    def initialize(uri, timeout: DEFAULT_TIMEOUT, log:)
      @uri = uri
      @log = log
      @timeout = timeout
    end

    def history
      fetch_all(add_uri("/history", page: 1)).to_a
    end

    protected def fetch_all(uri)
      return enum_for __method__, uri unless block_given?
      fetched = 0
      total = nil
      uri = Utils.merge_uri uri, pageSize: 200
      loop do
        Hash[URI.decode_www_form(uri.query || "")].
          slice("page", "pageSize").
          tap { |h| @log.debug "fetching %p of %s" % [h, uri] }
        resp = get_response! uri
        data = JSON.parse resp.body
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

    protected def add_uri(*args, &block)
      Utils.merge_uri @uri, *args, &block
    end

    protected def get_response!(uri)
      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = uri.scheme == 'https'
      %i[open ssl read write].each do |op|
        meth = :"#{op}_timeout="
        http.public_send meth, @timeout if http.respond_to? meth
      end

      ConnError.may_raise {
        http.start { http.request_get uri }
      }.tap { |resp|
        resp.kind_of? Net::HTTPSuccess \
          or raise "unexpected response: %p (%s)" % [resp, resp.body]
      }
    end
  end

  class Radarr < Basic
  end

  class Sonarr < Basic
  end
end # PVR

end # Utils

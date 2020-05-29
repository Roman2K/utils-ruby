require 'influxdb'
require 'pp'

module Utils::Influx
  DEFAULT_TIME_PREC = "ms".freeze

  def self.new_client(uri, **opts)
    unless URI === uri
      uri = "http://#{uri}" unless uri.include? "://"
      uri = URI uri
    end
    raise "missing db" if uri.path.sub(%r{^/}, "").empty?
    InfluxDB::Client.new url: uri, time_precision: DEFAULT_TIME_PREC, **opts
  end

  class WritesDebug
    def initialize(client, log, quiet: false, log_level: :info)
      @client = client
      @log = log
      @quiet = quiet
      @log_level = log_level

      @log.puts "logging Influx %p writes to %p" \
        % [client.config.database, @log.io]
    end

    private def method_missing(m, *args, &block)
      if m =~ /^write/
        args = @quiet ? quiet_args(args) : PP.pp(args, "").chomp
        @log.public_send @log_level, "Influx#%s(%s)" % [m, args]
        return
      end
      @client.public_send m, *args, &block
    end

    private def quiet_args(args)
      args.map { |obj|
        case obj
        when Array then "%d-array" % obj.size
        when Hash then "%d-hash" % obj.size
        else obj.class
        end
      }.join ", "
    end
  end # WritesDebug
end

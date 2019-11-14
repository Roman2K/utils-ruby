require 'influxdb'
require 'pp'

module Utils::Influx
  DEFAULT_TIME_PREC = "ms".freeze

  def self.new_client(uri)
    unless URI === uri
      uri = "http://#{uri}" unless uri.include? "://"
      uri = URI uri
    end
    db = uri.path.sub(%r{^/}, "")
    !db.empty? or raise "missing db"
    InfluxDB::Client.new db,
      host: uri.host,
      port: uri.port,
      time_precision: DEFAULT_TIME_PREC
  end

  class WritesDebug
    def initialize(client, log, quiet: false)
      @client, @log, @quiet = client, log, quiet
      @log.puts "logging Influx %p writes to %p" \
        % [client.config.database, @log.io]
    end

    private def method_missing(m, *args, &block)
      if m =~ /^write/
        args = @quiet ? quiet_args(args) : PP.pp(args, "").chomp
        @log.puts "Influx#%s(%s)" % [m, args]
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

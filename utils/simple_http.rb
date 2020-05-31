require 'net/http'
require 'json'

module Utils

class SimpleHTTP
  class Error < StandardError; end
  class InvalidJSONError < Error; end
  class NetError < Error; end

  def initialize(uri, timeout: nil, json: false, log: Log.new)
    @base_uri, @get_client = uri_or_client uri
    @timeout = timeout
    @type_config = TypeConf.new json: json
    @log = log
  end

  attr_reader :type_config

  private def start
    cli = @get_client[]
    if cli.started?
      yield cli
    else
      expect_net_err { cli.start }
      begin
        yield cli
      ensure
        cli.finish
      end
    end
  end

  private def expect_net_err
    yield
  rescue Net::ProtocolError, Net::HTTPExceptions
    raise NetError
  end

  private def uri_or_client(uri)
    if uri.respond_to?(:start) && uri.respond_to?(:request)
      if @timeout
        @log.warn "timeout won't be applied to previously instantiated client"
      end
      client, uri = uri, URI("/")
      return uri, ->{ client }
    end

    uri = URI uri
    get_client = -> do
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = (uri.scheme == 'https')
        %i[open ssl read write continue].each do |op|
          meth = :"#{op}_timeout="
          http.public_send meth, @timeout if http.respond_to? meth
        end
      end
    end

    [uri, get_client]
  end

  class TypeConf
    def initialize(opts)
      @json_in = @json_out = false
      update opts
    end

    attr_reader :json_in, :json_out

    def merge(opts)
      dup.update opts
    end

    def update(opts)
      opts = opts.dup
      @json_in = @json_out = opts.delete :json if opts.key? :json
      @json_in = opts.delete :json_in if opts.key? :json_in
      @json_out = opts.delete :json_out if opts.key? :json_out
      opts.empty? or raise "unrecognized opts: %p" % [opts.keys]
      self
    end
  end

  def get(path, *args, **opts, &block)
    req = new_req Net::HTTP::Get, path
    request req, *args, expect: [Net::HTTPOK], **opts, &block
  end

  def post(*args, **opts, &block)
    request_body Net::HTTP::Post, *args, expect: [Net::HTTPCreated],
      **opts, &block
  end

  def patch(*args, **opts, &block)
    request_body Net::HTTP::Patch, *args, expect: [Net::HTTPOK],
      **opts, &block
  end

  def delete(*args, **opts, &block)
    request_body Net::HTTP::Delete, *args, expect: [Net::HTTPOK],
      **opts, &block
  end

  private def new_req(cls, uri)
    uri = Utils.merge_uri(@base_uri, *uri)
    uri = uri.to_s unless uri.respond_to? :request_uri
    cls.new uri
  end

  private def request(req, expect:, **opts)
    @log["#{req.method} #{req.path}"].debug "executing HTTP request"
    json_out = @type_config.merge(opts).json_out
    req['Accept'] = 'application/json' if json_out
    yield req if block_given?
    case resp = start { |http| expect_net_err { http.request(req) } }
    when *expect
    else raise UnexpectedRespError.new(resp)
    end
    if json_out
      JSON.parse resp.body
    else
      resp
    end
  end

  class UnexpectedRespError < Error
    def initialize(resp)
      super "unexpected response: #{resp.code} (#{resp.body})"
      @resp = resp
    end
    attr_reader :resp
  end

  private def request_body(cls, path, payload, expect:, **opts)
    req = new_req cls, path
    if @type_config.merge(opts).json_in && !payload.kind_of?(String)
      req['Content-Type'] = "application/json"
      payload = begin
        JSON.dump payload 
      rescue JSON::ParserError
        raise InvalidJSONError
      end
    end
    req.body = payload
    request req, expect: expect, **opts
  end
end

end

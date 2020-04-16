require 'net/http'
require 'json'

module Utils

class SimpleHTTP
  def initialize(uri, timeout: nil, json: false, log: Log.new)
    @base_uri, @get_client = uri_or_client uri
    @timeout = timeout
    @type_config = TypeConf.new json: json
    @log = log
  end

  private def start
    cli = @get_client[]
    if cli.started?
      yield cli
    else
      cli.start { yield cli }
    end
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
    case resp = start { |http| http.request(req) }
    when *expect
    else raise "unexpected response: #{resp.code} (#{resp.body})"
    end
    if json_out
      JSON.parse resp.body
    else
      resp
    end
  end

  private def request_body(cls, path, payload, expect:, **opts)
    req = new_req cls, path
    if @type_config.merge(opts).json_in && !payload.kind_of?(String)
      req['Content-Type'] = "application/json"
      payload = JSON.dump payload 
    end
    req.body = payload
    request req, expect: expect, **opts
  end
end

end

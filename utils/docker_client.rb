require 'net_x/http_unix'
require 'open3'

module Utils

class DockerClient
  API_VER = "1.40"

  def initialize(uri, log:)
    @docker_host = self.class.fix_unix_url(uri) { _1 }.to_s
    @client = SimpleHTTP.new \
      self.class.fix_unix_url(uri) { NetX::HTTPUnix.new _1 },
      json: true,
      log: log["http"]
  end

  def self.fix_unix_url(uri)
    case uri.scheme
    when 'unix'
      yield \
        case uri.to_s
        when %r{^unix://.+} then $&
        else "unix://#{uri.path}"
        end
    else
      uri
    end
  end

  def get_json(path)
    @client.get path
  end

  def container_exec(id, *cmd, &block)
    Open3.popen3(
      {"DOCKER_HOST" => @docker_host},
      "docker", "exec", id, *cmd.map(&:to_s),
      &block
    )
  end

  def container_restart(id)
    @client.post "/containers/#{id}/restart", nil, expect: [Net::HTTPNoContent],
      json_out: false
  end
end

end

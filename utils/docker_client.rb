require 'net_x/http_unix'

module Utils

class DockerClient
  API_VER = "1.40"

  def initialize(uri)
    uri = NetX::HTTPUnix.new 'unix://' + uri.path if uri.scheme == 'unix'
    @client = SimpleHTTP.new uri, json: true
  end

  def get_json(path)
    @client.get path
  end
end

end

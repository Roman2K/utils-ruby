require 'pathname'

module Utils
  def self.util_autoload(name, path)
    autoload name, __dir__ + '/utils/' + path
  end

  util_autoload :Log, 'log'
  util_autoload :QBitTorrent, 'qbittorrent'

  def self.df(path, block_size)
    path = path.to_s if Pathname === path
    IO.popen(["df", "-B#{block_size}", path], &:read).
      tap { $?.success? or raise "df failed" }.
      split("\n").
      tap { |ls| ls.size == 2 or raise "unexpected number of lines" }.
      fetch(1).
      split(/\s+/).
      fetch(-3).
      chomp(block_size).to_f
  end

  def self.merge_uri(a, b=nil, params={})
    b, params = URI(""), b if b.kind_of?(Hash) && params == {}
    a, b = URI(a), URI(b)
    a.dup.tap do |a|
      a.path += b.path
      a.query = [a.query, b.query].compact.
        map { |qs| Hash[URI.decode_www_form qs] }.
        push(params.transform_keys &:to_s).
        inject({}) { |q,h| q.merge h }.
        yield_self { |h| URI.encode_www_form h unless h.empty? }
    end
  end

  module Fmt
    def self.duration(d)
      case
      when d < 60 then "%ds" % d
      when d < 3600 then m, d = d.divmod(60); "%dm%s" % [m, duration(d)]
      when d < 86400 then h, d = d.divmod(3600); "%dh%s" % [h, duration(d)]
      else ds, d = d.divmod(86400); "%dd%s" % [ds, duration(d)]
      end.sub /([a-z])(0[a-z])+$/, '\1'
    end
  end
end

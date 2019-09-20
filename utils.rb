require 'pathname'
require 'timeout'
require_relative 'utils/pathdiff'

module Utils
  def self.util_autoload(name, path)
    autoload name, __dir__ + '/utils/' + path
  end

  util_autoload :Log, 'log'
  util_autoload :QBitTorrent, 'qbittorrent'
  util_autoload :PVR, 'pvr'
  util_autoload :Fmt, 'fmt'
  util_autoload :Conf, 'conf'

  def self.df(path, block_size)
    path = path.to_s if Pathname === path
    IO.popen(["df", "-B#{block_size}", path], &:read).
      tap { $?.success? or raise "df failed" }.
      split("\n").
      tap { |ls| ls.size == 2 or raise "unexpected number of lines" }.
      fetch(1).split(/\s+/).
      fetch(-3).chomp(block_size).to_f
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

  def self.retry(attempts, *excs, wait: nil)
    attempts > 0 or return
    cur = 1
    begin
      return yield cur
    rescue => exc
      case exc
      when *excs
      else raise
      end
      attempts -= 1
      attempts > 0 or raise
      cur += 1
      if w = wait
        w = w[] if Proc === w
        $stderr.puts "waiting %.1fs before retrying..." % [w]
        sleep w
      end
      retry
    end
  end

  def self.try_conn!(*args, &block)
    ConnError.may_raise do
      Timeout.timeout *args, &block
    end
  end

  class ConnError < StandardError
    def self.may_raise
      yield
    rescue Timeout::Error, Errno::ECONNREFUSED
      raise self
    end

    def to_s
      "connection error: %p" % cause
    end
  end
end

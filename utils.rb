require 'pathname'
require 'timeout'
require 'uri'
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
  util_autoload :Influx, 'influx'
  util_autoload :SimpleHTTP, 'simple_http'
  util_autoload :IOUtils, 'ioutils'

  def self.df(path, block_size, col: :avail)
    col = {avail: -3, used: -4}.fetch col
    path = path.to_s if Pathname === path
    IO.popen(["df", "-B#{block_size}", path], &:read).
      tap { $?.success? or raise "df failed" }.
      split("\n").
      tap { |ls| ls.size == 2 or raise "unexpected number of lines" }.
      fetch(1).split(/\s+/).
      fetch(col).chomp(block_size).to_f
  end

  def self.df_bytes(path, **opts, &block)
    (df(path, 'K', **opts, &block) * 1024).to_i
  end

  def self.du_bytes(path)
    IO.popen(["du", "-sb", path], &:read).
      tap { $?.success? or raise "du failed" }.
      split("\n").
      tap { |ls| ls.size == 1 or raise "unexpected number of lines" }.
      fetch(0).split(/\s+/).
      fetch(0).to_i
  end

  def self.merge_uri(a, b=nil, params={})
    b, params = URI(""), b if b.kind_of?(Hash) && params == {}
    a, b = URI(a), URI(b)
    check_endpoints_mismatch! a, b
    a.dup.tap do |a|
      a.path = concat_uri_paths a.path, b.path
      a.query = [a.query, b.query].compact.
        map { |qs| Hash[URI.decode_www_form qs] }.
        push(params.transform_keys &:to_s).
        inject({}) { |q,h| q.merge h }.
        yield_self { |h| URI.encode_www_form h unless h.empty? }
    end
  end

  def self.concat_uri_paths(a, b)
    a = a.sub %r[/+$], '' if b.start_with? '/'
    a = "#{a}#{b}"
    a << '/' if a.empty?
    a
  end

  def self.check_endpoints_mismatch!(a, b)
    mismatches = %i[host port scheme].select do |component|
      y = b.public_send(component) or next false
      x = a.public_send(component)
      y != x
    end
    raise URIEndpointMismatch, mismatches if !mismatches.empty?
  end

  class URIEndpointMismatch < StandardError
    def initialize(components)
      super "URI endpoint mismatch: %s" % [components * ", "]
    end
  end

  def self.retry(attempts, *excs, wait: nil, &block)
    r = Retrier.new(attempts, *excs)
    r.wait = wait
    r.attempt &block
  end

  class Retrier
    def initialize(attempts, *excs)
      @attempts, @excs = attempts, excs
      @before_wait = -> w do
        $stderr.puts "waiting %.1fs before retrying..." % [w]
      end
    end

    attr_writer :wait, :on_err, :before_wait

    def attempt
      attempts = @attempts
      attempts > 0 or return
      cur = 1
      begin
        return yield cur
      rescue => exc
        case exc
        when *@excs
          @on_err[exc] if @on_err
        else raise
        end
        attempts -= 1
        attempts > 0 or raise
        cur += 1
        if w = @wait
          w = w[] if Proc === w
          @before_wait[w] if @before_wait
          sleep w
        end
        retry
      end
    end
  end

  def self.is_unavail?(err)
    ConnError === err \
      || /^unexpected response\b.*\b502\b/ === err.message
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

  def self.home; ENV.fetch "HOME" end

  def self.expand_tilde(path)
    was_pathname = Pathname === path
    path = path.to_s
    path =
      case path
      when %r{\A~(/.*|\z)} then home + $1
      when %r{\A~([^~].*)} then "#{home}/#{$1}"
      else path
      end
    path = Pathname path if was_pathname
    path
  end
end

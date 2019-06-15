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
end

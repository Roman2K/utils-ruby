require 'open3'

module Utils

module DU
  class RaceCondError < StandardError; end

  def self.bytes(path)
    path = path.to_s if Pathname === path
    out, err, st = Open3.capture3 "du", "-sb", path
    if !st.success?
      if err =~ /^du: cannot access '.+?': No such file/i \
        && err !~ /^du: cannot access '#{Regexp.escape path}': No such file/i \
      then
        ##
        # Test:
        #
        # ```sh
        # while : ; do
        #   for n in {a..z}; do touch $n; sleep 0.01; rm $n; done
        # done
        # ```
        #
        raise RaceCondError
      end
      raise "du failed"
    end
    out.split("\n").
      tap { |ls| ls.size == 1 or raise "unexpected number of lines" }.
      fetch(0).split(/\s+/, 2).
      tap { |cols| cols.size == 2 or raise "unexpected number of columns" }.
      fetch(0).to_i
  end

  def self.bytes_retry(*args, **opts, &block)
    Utils.retry 5, RaceCondError, wait: ->{ 1 + rand } do
      bytes *args, **opts, &block
    end
  end
end

end

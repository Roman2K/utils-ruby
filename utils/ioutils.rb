module Utils::IOUtils

class Table
  def initialize
    @rows = []
    @cols = []
  end

  attr_reader :cols

  def col(i)
    @cols[i] ||= Column.new
  end

  def <<(row)
    row = row.dup
    row.each_with_index do |s,i|
      cell = row[i] = Cell.new s
      col(i).add_widths cell
    end
    @rows << row
    self
  end

  def write_to(io)
    if @rows.empty?
      io.puts "[empty table]"
      return
    end
    @rows.each do |row|
      io.puts row.zip(@cols).map { |cell, col|
        "%#{col.align_sign}*s" % [col.width(cell), cell.to_s]
      }.join "  "
    end
    nil
  end

  class Column
    def initialize
      @wplain = 0
      @align = ALIGNS.keys.first
    end

    ALIGNS = {right: "", left: "-"}.freeze

    def align=(a)
      ALIGNS.key? a or raise ArgumentError, "invalid align type"
      @align = a
    end

    def align_sign
      ALIGNS.fetch @align
    end

    def add_widths(cell)
      @wplain = [@wplain, cell.wplain].max
    end

    def width(cell)
      @wplain + cell.wcodes
    end
  end

  class Cell
    def initialize(s)
      @s = s.to_s
      @wplain, @wcodes = Color.size @s
    end

    def to_s; @s end
    attr_reader :wplain, :wcodes
  end
end

# Based on Roman2K/scat/ansirefresh
class Refresh
  CLEAR = "\x1b[2K\r".freeze
  MOVE_UP_CLEAR = "\x1b[0A\x1b[K\r".freeze

  def initialize(io)
    @io = io
    @count, @flushed = 0, false
  end

  def flush
    @flushed = true
    self
  end

  def print(*ss)
    may_clear
    ss.map! &:to_s
    @io.print *ss
    ss.each { |s| count_lines s }
    nil
  end

  def <<(s)
    print s
    self
  end

  def puts(*ss)
    may_clear
    ss.map! &:to_s
    @io.puts *ss
    ss.each { |s| count_lines s }
    @count += ss.size - ss.count { |s| s.end_with? "\n" }
    @count += 1 if ss.empty?
    nil
  end

  private def may_clear
    @flushed or return
    @io.print CLEAR
    @io.print MOVE_UP_CLEAR * @count
    @count, @flushed = 0, false
  end

  private def count_lines(s)
    @count += s.count "\n"
  end
end

class Throttle
  def self.every(secs)
    new secs
  end

  def initialize(delay)
    @delay = delay
    @last = @last_time = nil
  end

  def apply &block
    if @last_time.nil? || Time.now - @last_time >= @delay
      block.call
      @last, @last_time = nil, Time.now
    else
      @last = block
    end
  end

  def finish
    @last or return
    @last.call
    @last = nil
  end
end

module Color
  CODES = {
    green: 32,
    red: 31,
    yellow: 33,
    magenta: 35,
    cyan: 36,
    dim: 90,
  }

  def self.[](s, code)
    return s if code.nil?
    code = CODES.fetch code
    "\e[#{code}m#{s}\e[0m"
  end

  ANSI_CODE_RE = /\e\[.+?m/

  def self.size(s)
    codes = 0
    plain = s.gsub(ANSI_CODE_RE) { codes += $&.size; "" }.size
    [plain, codes]
  end

  def self.disable!
    def self.[](s, _)
      s
    end
  end
end

end

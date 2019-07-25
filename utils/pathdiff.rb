require 'json'
require 'shellwords'

module Utils
  ##
  # Git-style path diffing for renamings and moves between folders
  #
  def self.path_diff(a, b)
    diff = IO.popen "bash", 'w+' do |p|
      anon_pipe = -> path do
        path = path.to_s if Pathname === path
        contents = path.chars.map { |c| JSON.dump c }.join("\n")
        "<(echo -e #{Shellwords.escape contents})"
      end
      p.puts "diff -y #{anon_pipe[a]} #{anon_pipe[b]}"
      p.close_write
      p.read
    end
    [0,1].include? $?.exitstatus or raise "diff command failed"

    res, patch = [], ["", ""]
    may_append_patch = -> do
      patch.any? { |s| !s.empty? } or break
      res << "{#{patch.join ' => '}}"
      patch.each &:clear
    end

    diff.split("\n").each do |line|
      op = nil
      a, b = line.split.tap do |arr|
        arr.delete_if { |c| c !~ /^"/ or next false; op = c; true }
        (1..2) === arr.size or raise "unexpected number of operands"
        arr.map! { |c| JSON.parse c }
      end
      case op
      when '>'
        !b or raise "unexpected operands for >"
        patch.fetch(1) << a
      when '<'
        !b or raise "unexpected operands for <"
        patch.fetch(0) << a
      when '|'
        a && b or raise "unexpected operands for |"
        patch.zip([a,b]) { |s,c| s << c }
      when nil
        a && b && a == b or raise "unexpected operands for equality"
        may_append_patch[]
        res << a
      else
        raise "unknown operand"
      end
    end
    may_append_patch[]

    res.join
  end
end

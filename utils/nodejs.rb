require 'open3'

class NodeJS
  def initialize(cmd=["node"], env: {})
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3 env, *cmd,
      File.join(__dir__, "nodejs_eval.js")

    @stderr_thr = stream_loop @stderr do |line|
      if @stderr_cap
        @stderr_cap << line 
      elsif line != :close
        pp stderr: line
      end
    end

    @req_id = 0
    @outq = Queue.new
    @stdout_thr = stream_loop @stdout do |line|
      @outq << line
    end
  end

  private def stream_loop(io)
    Thread.new do
      Thread.abort_on_exception = true
      while line = io.gets
        yield line
      end
      yield :close
    end
  end

  def eval(js)
    stderr = @stderr_cap = []
    id = send_js js
    res = @outq.shift
    @stderr_cap = nil
    if res == :close
      raise ExitError, "node process exited unexpectedly" \
        " (stderr: `#{(stderr - %i[close]).map(&:strip) * " "}`)"
    end
    res = JSON.parse res
    res.fetch("id") == id or raise "responses out of order"
    val = res.fetch "value"
    case res.fetch "status"
    when "ok" then val
    when "err" then raise EvalFailure, "eval promise failure: #{val.inspect}"
    else raise "invalid status"
    end
  end

  class Error < StandardError; end
  class ExitError < Error; end
  class EvalFailure < Error; end

  private def send_js(src)
    id = @req_id += 1
    JSON.dump({id: id, src: src}, @stdin)
    @stdin.write "\n"
    id
  end

  def close
    if !@stdin.closed?
      begin
        send_js "process.exit(0);"
      rescue Errno::EPIPE
      end
      @stdin.close
    end
    @stderr_thr.join
    @stdout_thr.join
    @wait_thr.join
  end
end

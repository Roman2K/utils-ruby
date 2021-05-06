require 'minitest/autorun'
require_relative '../utils'

module Utils

class NodeJSTest < Minitest::Test
  def setup; @node = NodeJS.new end
  def teardown; @node.close end

  def test_eval
    res = @node.eval "1"
    assert_equal 1, res
    res = @node.eval "`ok`"
    assert_equal "ok", res
  end

  def test_eval_throw
    err = assert_raises NodeJS::ExitError do
      @node.eval "throw `ok`"
    end
    assert_match /throw `ok`.+exception was thrown/, err.message
  end

  def test_eval_promise
    res = @node.eval <<-JS
      new Promise((resolve, fail) => {
        process.nextTick(() => resolve(1))
      })
    JS
    assert_equal 1, res

    err = assert_raises NodeJS::EvalFailure do
      @node.eval <<-JS
        new Promise((resolve, fail) => {
          process.nextTick(() => fail("err"))
        })
      JS
    end
    assert_match /eval promise failure: "err"/, err.message
  end
end

end

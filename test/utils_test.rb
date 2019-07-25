require 'minitest/autorun'
require_relative '../utils'

class UtilsTest < Minitest::Test
  def test_merge_uri
    assert_equal URI("http://v.xyz/a/b"),
      Utils.merge_uri("http://v.xyz/a", "/b")

    assert_equal URI("http://v.xyz/a/b?c=1"),
      Utils.merge_uri("http://v.xyz/a?c=1", "/b")

    assert_equal URI("http://v.xyz/a?c=1&d=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", "?d=2")

    assert_equal URI("http://v.xyz/a?c=1&d=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", d: 2)

    assert_equal URI("http://v.xyz/a?c=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", c: 2)
  end

  def test_retry
    err = StandardError

    # no attempt
    run = 0; Utils.retry(0, err) { run += 1 }
    assert_equal 0, run

    # successful attempt
    run = 0; Utils.retry(2, err) { run += 1 }
    assert_equal 1, run

    # retries after err
    attempts = []
    run = 0; Utils.retry(2, err) { run += 1; raise err if run == 1 }
    assert_equal 2, run

    # raises if all attempts fail
    run = 0
    assert_raises err do
      Utils.retry(2, err) { run += 1; raise err }
    end
    assert_equal 2, run

    # yielded attempt number
    attempts = []
    Utils.retry(2, err) { |n| attempts << n; raise err if n < 2 }
    assert_equal [1,2], attempts

    # return value
    res = Utils.retry(2, err) { :val }
    assert_equal :val, res

    # === matching
    err = -> e { e.message == "some err" }
    run = 0; Utils.retry(2, err) { |n| run += 1; raise "some err" if run == 1 }
    assert_equal 2, run
  end

  def test_path_diff
    assert_equal "foo/bar",
      Utils.path_diff("foo/bar", "foo/bar")

    assert_equal "foo{ => xy}/bar",
      Utils.path_diff("foo/bar", "fooxy/bar")

    assert_equal "foo{ => xy}/b{a => yz}r",
      Utils.path_diff("foo/bar", "fooxy/byzr")

    assert_equal "foo{xy => }/b{yz => a}r",
      Utils.path_diff("fooxy/byzr", "foo/bar")

    assert_equal "foo/b{a => }r",
      Utils.path_diff("foo/bar", "foo/br")

    assert_equal "foo/ba{r => }",
      Utils.path_diff("foo/bar", "foo/ba")
  end
end

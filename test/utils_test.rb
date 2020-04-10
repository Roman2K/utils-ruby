require 'minitest/autorun'
require_relative '../utils'

class UtilsTest < Minitest::Test
  def test_merge_uri
    assert_equal URI("http://v.xyz/a/b"),
      Utils.merge_uri("http://v.xyz/a", "/b")

    assert_equal URI("http://v.xyz/b"),
      Utils.merge_uri("http://v.xyz", "/b")

    assert_equal URI("http://v.xyz/b"),
      Utils.merge_uri("http://v.xyz/", "/b")

    assert_equal URI("http://v.xyz/a/b?c=1"),
      Utils.merge_uri("http://v.xyz/a?c=1", "/b")

    assert_equal URI("http://v.xyz/a?c=1&d=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", "?d=2")

    assert_equal URI("http://v.xyz/a?c=1&d=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", d: 2)

    assert_equal URI("http://v.xyz/a?c=2"),
      Utils.merge_uri("http://v.xyz/a?c=1", c: 2)

    assert_equal URI("http://foo"),
      Utils.merge_uri("http://foo", "http://foo")

    assert_equal URI("http://foo/bar"),
      Utils.merge_uri("http://foo", "http://foo/bar")

    assert_equal URI("http://foo/bar/baz"),
      Utils.merge_uri("http://foo/bar", "http://foo/baz")

    err = assert_raises Utils::URIEndpointMismatch do
      Utils.merge_uri("http://foo", "https://foo")
    end
    assert_match /: port, scheme/, err.message

    assert_raises Utils::URIEndpointMismatch do
      Utils.merge_uri("http://foo:81", "http://foo")
    end

    assert_raises Utils::URIEndpointMismatch do
      Utils.merge_uri("http://foo", "http://foox")
    end
  end

  def test_concat_uri_paths
    concat = Utils.method :concat_uri_paths
    assert_equal "/", concat["", ""]
    assert_equal "/", concat["/", ""]
    assert_equal "/", concat["", "/"]
    assert_equal "/a", concat["/", "/a"]
    assert_equal "/b/", concat["/b", "/"]
    assert_equal "/b/c", concat["/b", "/c"]
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
    assert_equal "",
      Utils.path_diff("", "")

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

    assert_equal "fo{ => ' '}o/ba{r => }",
      Utils.path_diff("foo/bar", "fo o/ba")

    assert_equal \
      "{'► ' => CA}P{la => 'TAINE ROSHI - Freest'}y{ => le} { => 'COUVRE FEU Hors-Série sur OKLM R'}a{ll => dio}",
      Utils.path_diff(
        "► Play all",
        "CAPTAINE ROSHI - Freestyle COUVRE FEU Hors-Série sur OKLM Radio"
      )
  end
end

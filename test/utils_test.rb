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
end

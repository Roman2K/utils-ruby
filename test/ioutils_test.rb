require 'minitest/autorun'
require_relative '../utils'

module Utils

class IOUtilsTest < Minitest::Test
  def test_Table
    t = IOUtils::Table.new

    t << ["a", "b", "c"]
    assert_equal <<-EOS, out(t)
a  b  c
    EOS

    t << ["a", "foo", "c"]
    assert_equal <<-EOS, out(t)
a    b  c
a  foo  c
    EOS

    t << ["a", IOUtils::Color["x", :red], "c"]
    assert_equal <<-EOS, out(t)
a    b  c
a  foo  c
a    \e[31mx\e[0m  c
    EOS

    t << ["a", "\e[0mx\e[0m", "c"]
    assert_equal <<-EOS, out(t)
a    b  c
a  foo  c
a    \e[31mx\e[0m  c
a    \e[0mx\e[0m  c
    EOS
  end

  private def out(obj)
    StringIO.new.tap { |io| obj.write_to io }.string
  end
end

module IOUtils
  class ColorTest < Minitest::Test
    def test_pain_size
      s = Color.public_method :size
      assert_equal [0, 0], s[""]
      assert_equal [1, 0], s["a"]
      assert_equal [1, 9], s[Color["a", :red]]
      assert_equal [3, 9], s["x" + Color["a", :red] + "x"]
      assert_equal [4, 18], s["x" + Color["a", :red] + "x" + Color["b", :red]]
    end
  end
end

end

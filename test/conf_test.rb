require 'minitest/autorun'
require_relative '../utils'

module Utils

class ConfTest < Minitest::Test
  def test_brackets
    conf = Conf.new \
      a: 1,
      b: {
        c: 2,
      },
      some_str: "foo",
      home: "~",
      some_path: "~/foo",
      some_path2: "~foo",
      some_path3: "~~foo"

    assert_equal 1, conf[:a]
    assert_equal 1, conf["a"]
    assert_equal 2, conf[:b][:c]
    assert_equal 2, conf["b.c"]
    assert_equal 2, conf.lookup("b.c")
    assert_nil conf.lookup("b.xxx")

    err = assert_raises KeyError do
      conf[:x]
    end
    assert_match /missing key: x/, err.message

    err = assert_raises KeyError do
      conf["b.x"]
    end
    assert_match /missing key: b\.x/, err.message

    Conf.stub :home, "/my/home" do
      assert_equal "/my/home", conf[:home]
      assert_equal "/my/home/foo", conf[:some_path]
      assert_equal "/my/home/foo", conf[:some_path2]
      assert_equal "~~foo", conf[:some_path3]
    end
  end

  def test_include
    conf = Conf.new \
      a: 1,
      b: {include: __dir__ + "/conf_incl_b.yml"},
      c: {include: __dir__ + "/conf_incl_c.yml"}
    assert_equal 1, conf[:a]
    assert_equal 2, conf[:b]
    assert_equal 3, conf[:c][:d]

    resolve = -> path do
      conf.resolve_path(Pathname(path)).to_s
    end

    conf = Conf.new({})
    assert_equal "/a",  resolve["/a"]
    assert_equal "./a", resolve["./a"]
    assert_equal "a",   resolve["a"]

    conf = Conf.new({}, load_path: ["some/dir"])
    assert_equal "/a",          resolve["/a"]
    assert_equal "some/dir/a",  resolve["./a"]
    assert_equal "a",           resolve["a"]
  end
end

end

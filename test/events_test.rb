require 'minitest/autorun'
require_relative '../utils'

module Utils

class EventsTest < Minitest::Test
  def test_on
    evs = Events.new.declare :foo

    err = assert_raises RuntimeError do
      evs.on(:bar) {}
    end
    assert_match /unknown ev/, err.message

    called = []
    evs.on :foo do |*args|
      called << args
    end

    evs.emit :foo, 1
    assert_equal [[1]], called

    called2 = []
    evs.on :foo, once: true do |*args|
      called2 << args
    end

    evs.emit :foo, 2
    assert_equal [[1], [2]], called
    assert_equal [[2]], called2

    evs.emit :foo, 3
    assert_equal [[1], [2], [3]], called
    assert_equal [[2]], called2
  end

  def test_on_keyed
    evs = Events.new.declare :foo

    called = []
    evs.on :foo, "some key" do
      called << :aaa
    end

    evs.emit :foo
    assert_equal [:aaa], called

    evs.on :foo, "some key" do
      called << :bbb
    end

    evs.emit :foo
    assert_equal [:aaa, :bbb], called
  end

  def test_unregister
    evs = Events.new.declare :foo
    reg = evs.reg_on(:foo) {}
    reg2 = evs.reg_on(:foo, once: true) {}

    evs.unregister reg
    assert_raises Events::InvalidRegError do
      evs.unregister reg
    end

    evs.unregister reg2
    assert_raises Events::InvalidRegError do
      evs.unregister reg2
    end
  end

  def test_unregister_after_fired
    evs = Events.new.declare :foo

    called = 0
    reg = evs.reg_on(:foo) { called += 1 }

    called2 = 0
    reg2 = evs.reg_on(:foo, once: true) { called2 += 1 }

    evs.emit :foo
    assert_equal 1, called
    assert_equal 1, called2

    evs.emit :foo
    assert_equal 2, called
    assert_equal 1, called2

    evs.unregister reg
    assert_raises Events::InvalidRegError do
      evs.unregister reg
    end

    evs.unregister reg2
    assert_raises Events::InvalidRegError do
      evs.unregister reg2
    end
  end
end

end

require 'minitest/autorun'
require_relative '../utils'
require 'bigdecimal'

module Utils

class FmtTest < Minitest::Test
  def test_duration
    fmt = Fmt.public_method :duration
    assert_equal "123ms", fmt.(0.123)
    assert_equal "1s", fmt.(1)
    assert_equal "1s", fmt.(1.01)
    assert_equal "1.2s", fmt.(1.2)
  end
  def test_dec_prec
    assert_equal 1, dec("2").prec
    assert_equal 1, dec("2.0").prec
    assert_equal 2, dec("2.01").prec
  end

  def test_dec_to_s
    assert_equal "2.0", dec("2").to_s
    assert_equal "2", dec("2").to_s(z: false)
    assert_equal "2", dec("2").to_s(0)
    assert_equal "2.0", dec("2").to_s(1)
    assert_equal "2.00", dec("2").to_s(2)
    assert_equal "2", dec("2").to_s(2, z: false)
    assert_equal "2.01", dec(2.01).to_s(2)
    assert_equal "2.00", dec(2).to_s(2)

    assert_equal "2", dec("2.01").to_s(0)
    assert_equal "2.0", dec("2.01").to_s(1)
    assert_equal "2.01", dec("2.01").to_s(2)
    assert_equal "2.010", dec("2.01").to_s(3)
    assert_equal "2.01", dec("2.01").to_s(3, z: false)

    assert_equal "0.00000", dec("0").to_s(5)
    assert_equal "0.00270", dec("0.0027").to_s(5)
    assert_equal "0.00270", dec("0.2696481e-2").to_s(5)
  end

  private def dec(d)
    d = BigDecimal d if String === d
    Fmt.dec d
  end

  def test_NumFmt
    fmt = Fmt::NumFmt.new(1000, ['', 'k', 'm'])
    assert_equal "-1", fmt.format(-1)
    assert_equal "0", fmt.format(0)
    assert_equal "1", fmt.format(1)
    assert_equal "1", fmt.format(1, 1)
    assert_equal "999", fmt.format(999)
    assert_equal "1k", fmt.format(1000, 0)
    assert_equal "1.9k", fmt.format(1900, 1)
    assert_equal "2k", fmt.format(1900)
    assert_equal "1.5k", fmt.format(1500, 1)
    assert_equal "2k", fmt.format(1500)
    assert_equal "1000m", fmt.format(1_000_000_000, 0)
    assert_equal "1000m", fmt.format(1_000_000_001, 0)
    assert_equal "1 KiB", Fmt::SIZE_FMT.format(1024)
  end
end

end # Utils

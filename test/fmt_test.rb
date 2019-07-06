require 'minitest/autorun'
require_relative '../utils'
require 'bigdecimal'

module Utils

class FmtTest < Minitest::Test
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
end

end # Utils

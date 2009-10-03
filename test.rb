require 'cards'
require 'test/unit'

class TDATestSuite < Test::Unit::TestCase
  def test_deck_full
    deck = TDA::Deck.new
    assert 70 == deck.length
  end
end

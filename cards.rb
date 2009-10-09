
module TDA
  class Deck < Array
    def initialize
      @discards = []
      Deck.load(self)
      reshuffle

      # Testing code
      # Restack the deck so desired card-to-test shows up.
      #
      self.unshift self.detect {|card| card.class.to_s.include?"Copper" }
      self.uniq!
    end

    #def stack_deck
      #self.unshift self.detect {|card| card.class.to_s.include?"Silver" }
      #self.uniq!
    #end

    def draw(amt)
      cards = []
      if amt > self.length
        remainder = amt - self.length
        self.length.times do |i| cards << self.shift end
        reshuffle
        remainder.times do |i| cards << self.shift end
      else
        amt.times do |i| cards << self.shift end
      end
      cards
    end

    def reshuffle
      @discards.each { |card| self << card }
      self.size.times do |src|
        dest = rand(self.size).round
        t = self[src]
        self[src] = self[dest]
        self[dest] = t
      end
    end

    def last_discard
      @discards.last
    end

    def discard(card)
      @discards << card
    end

    def self.load(deck)
      # Add one of each non-dragon card.
      TDA::Card.constants.each_with_index { |name, index|
        card = TDA::Card.const_get(name).new unless (name == "Card" || name[-6..-1]== "Dragon")
        deck << card if card && (card.mortal? || card.dragon_god? || card.undead_dragon?)
      }

      [1, 2, 3, 5,  7,  9].each { |str| deck << TDA::Card::BlackDragon.new(str)  }
      [1, 2, 4, 7,  9, 11].each { |str| deck << TDA::Card::BlueDragon.new(str)   }
      [1, 2, 4, 5,  7,  9].each { |str| deck << TDA::Card::BrassDragon.new(str)  }
      [1, 3, 6, 7,  9, 11].each { |str| deck << TDA::Card::BronzeDragon.new(str) }
      [1, 3, 5, 7,  8, 10].each { |str| deck << TDA::Card::CopperDragon.new(str) }
      [2, 4, 6, 9, 11, 13].each { |str| deck << TDA::Card::GoldDragon.new(str)   }
      [1, 2, 4, 6,  8, 10].each { |str| deck << TDA::Card::GreenDragon.new(str)  }
      [2, 3, 5, 8, 10, 12].each { |str| deck << TDA::Card::RedDragon.new(str)    }
      [2, 3, 6, 8, 10, 12].each { |str| deck << TDA::Card::SilverDragon.new(str) }
      [1, 2, 3, 4,  6,  8].each { |str| deck << TDA::Card::WhiteDragon.new(str)  }
    end
  end

  module Card
    class Card
      attr_reader :strength

      KNOWN_PROPERTIES = [
        :dragon, :mortal, :good, :evil, :god, :undead
      ].freeze
      
      def initialize(strength, properties, power = nil)
        @strength = strength
        @properties = properties.to_s.split('_')
        @properties.reject! { |prop| KNOWN_PROPERTIES.include? prop }
        @power = power || Proc.new { |api| }
      end
      
      def trigger(api)
        @power.call(api)
      end

      def to_s
        name = self.class.name
        "#{name[name.rindex(':')+1..-1]} #{@strength}"
      end

      def test_properties(properties)
        properties.split('_').all? { |prop| @properties.include? prop }
      end

      def method_missing(id, *args, &block)
        return test_properties($1) if id.to_s =~ /^(\w+)\?$/
        super
      end
    end

    class Archmage < Card
      def initialize
        super(9, :mortal)
      end
    end

    class Bahamut < Card
      def initialize
        super(13, :good_dragon_god)
      end
    end

    class BlackDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon, Proc.new { |api|
          api.current_player_takes_2_gold_from_stakes
        })
      end
    end

    class BlueDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon)
      end
    end

    class BrassDragon < Card
      def initialize(strength)
        super(strength, :good_dragon)
      end
    end

    class BronzeDragon < Card
      def initialize(strength)
        super(strength, :good_dragon)
      end
    end

    class CopperDragon < Card
      def initialize(strength)
        super(strength, :good_dragon, Proc.new { |api|
          api.deck.discard api.current_player.flight.delete(self)
          api.current_player.add_to_flight api.deck.draw(1).first
          api.current_player.flight.last.trigger(api)
        })
      end
    end

    class Dracolich < Card
      def initialize
        super(10, :undead_dragon)
      end
    end

    class Dragonslayer < Card
      def initialize
        super(8, :mortal)
      end
    end

    class Druid < Card
      def initialize
        super(6, :mortal, Proc.new { |api| 
          api.current_player_pays_1_gold_to_stakes
          api.weakest_flight_wins!
        })
      end
    end

    class Fool < Card
      def initialize
        super(3, :mortal)
      end
    end

    class GoldDragon < Card
      def initialize(strength)
        super(strength, :good_dragon)
      end
    end

    class GreenDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon)
      end
    end

    class Priest < Card
      def initialize
        super(5, :mortal)
      end
    end

    class Princess < Card
      def initialize
        super(4, :mortal)
      end
    end

    class RedDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon)
      end
    end

    class SilverDragon < Card
      def initialize(strength)
        super(strength, :good_dragon, Proc.new { |api|
          api.players_with_flight_of_good_dragon_draws_1
        })
      end
    end

    class Thief < Card
      def initialize
        super(7, :mortal, Proc.new { |api|
          api.current_player_takes_7_gold_from_stakes
          api.current_player_discards_1
        })
      end
    end

    class Tiamat < Card
      def initialize
        super(13, :evil_dragon_god)
      end
    end

    class WhiteDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon)
      end
    end

  end
end


module TDA
  class Deck < Array
    def initialize
      @discards = []
      TDA.load_cards(self)
      reshuffle
    end

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

    def reshuffle(pristine = false)
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
  end

  def TDA.load_cards(deck)
    # Add one of each non-dragon card.
    TDA::Card.constants.each { |name|
      deck << TDA::Card.const_get(name).new unless name[-6..-1] == 'Dragon' || name.class != TDA::Card::Card
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

  module Card
    class Card
      attr_accessor :strength, :type
      
      def initialize(strength, type, power = nil)
        @strength = strength
        @type = type
        @power = power || Proc.new { |controller| }
      end
      
      def trigger(controller)
        @power.call(controller)
      end

      def to_s
        name = self.class.name
        "#{name[name.rindex(':')+1..-1]} #{@strength}"
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
        super(strength, :evil_dragon)
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
        super(strength, :good_dragon)
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
        super(6, :mortal)
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
        super(strength, :good_dragon)
      end
    end

    class Thief < Card
      def initialize
        super(7, :mortal)
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

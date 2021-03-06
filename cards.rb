
module TDA
  class Deck < Array
    def initialize
      @discards = []
      Deck.load(self)
      reshuffle

      # Testing code
      # Restack the deck so desired card-to-test shows up.
      #
      stack_deck
    end

    def stack_deck
      self.unshift self.detect {|card| card.class.to_s.include?"slayer" }
      self.uniq!
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

    def draw_first
      self.draw(1).first
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
      ["Archmage", "Bahamut", "Dracolich", "Dragonslayer", "Druid", "Fool", "Priest", "Princess", "Thief", "Tiamat"].each { |name|
        deck << TDA::Card.const_get(name).new
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
    # Abstract Class
    class SetOfCards < Array
      def push(obj)
        return nil unless obj.is_a? TDA::Card::Card
        super
      end

      def <<(obj)
        return nil unless obj.is_a? TDA::Card::Card
        super
      end

      def to_s
        set = ""
        each_with_index { |card, index|
          set << "#{"%2d" % index}. #{card}\r\n"
        }
        set
      end
    end

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
        @power.call(api) unless @power.nil?
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
        super(9, :mortal, Proc.new { |api|
          #api.current_player_copies_power_from_ante
        })
      end
    end

    class Bahamut < Card
      def initialize
        super(13, :good_dragon_god, Proc.new { |api|
          players = api.players_with_flight_of_good_dragon & api.players_with_flight_of_evil_dragon
          players.delete api.current_player
          players.each { |player|
            api.pay_gold(player, 10, 'current_player')
          }
        })
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
        super(strength, :evil_dragon, Proc.new { |api|
          payment = api.current_player.flight.select { |card| card.evil_dragon? }.length
          list = []
          list << "Steal #{payment} from stakes"
          list << "Each player pays #{payment} to stakes"
          choice = api.current_player.receives_choice(list)
          if choice.include?"Steal"
            api.take_gold(:current_player, payment, :stakes)
          elsif choice.include?"pays"
            api.every_other_player.each { |player| api.pay_gold(player, payment, :stakes) }
          end
        })
      end
    end

    class BrassDragon < Card
      def initialize(strength)
        super(strength, :good_dragon)
      end
    end

    class BronzeDragon < Card
      def initialize(strength)
        super(strength, :good_dragon, Proc.new { |api|
          # How many ante cards do we care about?
          cards_to_receive = api.current_player.hand.space

          # Check the card one higher than the highest we automatically take.
          # Pose choice if third lowest is equal to second lowest.
          # 
          ante = api.ante
          # pose_choice if ante[-3].strength == ante[2].strength
        })
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
        super(10, :undead_dragon, Proc.new { |api|
          #api.current_player_copies_power_from_evil_dragon
        })
      end
    end

    class Dragonslayer < Card
      def initialize
        super(8, :mortal, Proc.new { |api|
          players = api.players_with_flights_stronger_than 0
          list = []
          players.each { |player| 
            player.flight.each { |card|
              list << "#{player.name}'s #{card}" if card.strength < 8
            }
          }
          choice = api.current_player.receives_choice(list)
          choice = list.index(choice)
          players.each { |player| 
            player.flight.each { |card| 
              api.deck.discard(card) and break if choice.zero?
              choice = choice - 1
          }}
        })
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
        super(3, :mortal, Proc.new { |api|
          api.current_player_pays_1_gold_to_stakes
          players = api.players_with_flights_stronger_than api.current_player.flight.strength
          api.send(:"current_player_draws_#{players.length}")
        })
      end
    end

    class GoldDragon < Card
      def initialize(strength)
        super(strength, :good_dragon, Proc.new { |api|
          api.send(:"current_player_draws_#{api.current_player.flight.good_dragons}")
        })
      end
    end

    class GreenDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon, Proc.new { |api|
          player = api.player_to_left
          list = player.hand.select { |card| card.strength < strength && card.evil_dragon? }
          choice = player.receives_choice(list << "Pay 5 gold")
          if choice == "Pay 5 gold"
            api.player_to_left_pays_5_gold_to_current_player 
          else
            api.player_to_left_gives_chosen_cards_to_current_player(choice)
          end
        })
      end
    end

    class Priest < Card
      def initialize
        super(5, :mortal, Proc.new { |api|
          api.current_player_leads_next_round!
        })
      end
    end

    class Princess < Card
      def initialize
        super(4, :mortal, Proc.new { |api|
          api.current_player_pays_1_gold_to_stakes
          cards = api.current_player.flight.select { |card| card.good_dragon? }
          cards.each { |card| card.trigger(api) }
        })
      end
    end

    class RedDragon < Card
      def initialize(strength)
        super(strength, :evil_dragon, Proc.new { |api|
          api.strongest_flight_not_current_player_pays_1_gold_to_current_player
          api.strongest_flight_not_current_player_gives_1_random_card_to_current_player
        })
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
        super(strength, :evil_dragon, Proc.new { |api|
          api.current_player_takes_3_gold_from_stakes unless api.players_with_flight_of_mortal.empty?
        })
      end
    end

  end
end

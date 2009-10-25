module TDA
  class Player
    class Hand < TDA::Card::SetOfCards
      MAX_LENGTH = 10

      def space
        MAX_LENGTH - self.length
      end
    end

    class Flight < TDA::Card::SetOfCards
      def strength
        self.inject(0) { |sum, card| sum + card.strength }
      end

      def strength_flight?
        self.length == 3 && self.all? { |card| card.strength == self.first.strength }
      end

      def type_flight?
        self.length == 3 && self.all? { |card| card.type == self.first.type }
      end
      alias :color_flight? :type_flight?

      def include_special?(properties)
        self.any? { |card| card.test_properties(properties) }
      end

      def count(condition)
        subset = self.select { |card| card.send(:"#{condition}?") }
        subset.length
      end

      def method_missing(id, *args, &block)
        return include_special?($1)  if id.to_s =~ /^include_(\w+)\?$/
        return count($1.to_s[0..-1]) if id.to_s =~ /^(\w+)s$/
        super
      end
    end
    
    attr_accessor :name, :hand, :flight
    def initialize(name, controller)
      @name = name
      @controller = controller
      @hand = Hand.new
      @message_queue = []
    end

    def enqueue_message message
      @message_queue << message
    end

    def show_hand_with_instruction message
      enqueue_message "#{message} (#{@hand.length}):\r\n#{@hand}"
    end

    def receives_choice(list)
      set = ""
      list.each_with_index { |choice, index|
        set << "#{"%2d" % index}. #{choice}\r\n"
      }
      enqueue_message "Make a choice:\r\n#{set}"
      list[self.receive_input.to_i]
    end

    def dequeue_message
      @message_queue.shift
    end

    def message_pending?
      !@message_queue.empty?
    end

    def receive_input=(message)
      case message
      when 'hand'
        enqueue_message @hand
      when 'pot'
        enqueue_message "Stakes: #{@controller.current_gambit.pot}"
      else
        @receive_input = message
      end
    end

    def receive_input
      while @receive_input.nil? ; end
      input = @receive_input
      @receive_input = nil
      input
    end

    def start_flight
      @flight = Flight.new
    end

    def add_to_flight(card)
      card = select_card(card) if card.is_a? Fixnum
      @flight << card
      @controller.broadcast "#{@name} plays #{@flight.last}. (Flight: #{@flight.join(', ')})"
      @flight.last
    end

    def complete_flight
      @flight = nil
    end

    def hoard
      @gold
    end

    def select_card(index)
      @hand.delete_at index
    end

    def draw_card(amt)
      cards = @hand.space >= amt ? amt : @hand.space
      @controller.deck.draw(cards).each { |card| @hand << card }
      @controller.broadcast "#{self.name} drew #{amt} cards. (Hand size: #{@hand.length})"
    end
    
    def receive_gold(amt)
      @gold ||= 0
      @gold = @gold + amt
      @controller.broadcast "#{self.name} receives #{amt} gold. (Hoard: #{@gold})"
    end
    alias :<< :receive_gold
    
    def pay_gold(amt)
      unless @gold < amt
        @gold = @gold - amt
        @controller.broadcast "#{self.name} pays #{amt} gold. (Hoard: #{@gold})"
        return amt
      end

      remainder = @gold
      @debt = amt - @gold
      @gold = 0
      @controller.broadcast "#{self.name} pays all their gold to the pot. (Debt: #{@debt})"
      remainder
    end
    alias :>> :pay_gold
    
    def method_missing(id, *args, &block)
      return receive_gold($1.to_i) if id.to_s =~ /receives_(\d+)_gold/
      return pay_gold(    $1.to_i) if id.to_s =~ /pays_(\d+)_gold/
      return draw_card(   $1.to_i) if id.to_s =~ /draws_(\d+)_cards/
      super
    end
  end
end

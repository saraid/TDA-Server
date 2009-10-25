require 'server'
require 'cards'
require 'player'

module TDA
  class Game
    PLAYER_CAP = 6

    attr_accessor :server
    def initialize
      @server = Server.new(self, PLAYER_CAP)
      @players = []

      # Start dancing!
      @server.start
    end

    def method_missing(id, *args, &block)
      return @server.send(id, *args, &block) if @server.respond_to? id
      super
    end

    def debug(msg)
      log("[DEBUG] #{msg}")
    end

    #
    # Player Stuff
    #
    
    attr_accessor :players
    def add_player player
      raise "Whoa, too many players." if @players.length >= PLAYER_CAP
      @players << player
      log "New player #{player.name} joined."
    end

    def all_players(&block)
      @players.each(&block)
    end

    def all_players_with_index(&block)
      @players.each_with_index(&block)
    end

    def broadcast(message)
      all_players { |player| player.enqueue_message message }
    end
    
    #
    # Powers API
    #

    class API
      def initialize(game)
        @game = game
        @players = @game.players
      end

      def strongest_flight
        @players.max { |a, b| a.flight.strength <=> b.flight.strength }
      end

      def strongest_flight_not_current_player
        @players.select { |player| player != current_player }.max { |a, b| a.flight.strength <=> b.flight.strength }
      end

      def most_cards
        @players.max { |a, b| a.hand.length <=> b.hand.length }
      end

      def deck
        @game.deck
      end

      def ante
        @game.current_gambit.ante
      end

      def current_player
        @game.current_player
      end

      def players_with_flights_stronger_than strength
        @players.select { |player| player.flight.strength > strength }
      end

      def players_with_flight_of condition
        @players.select { |player| player.flight.send(:"include_#{condition}?") }
      end

      def player_to_left_of player
        @players[@players.index(player)-1]
      end

      def player_to_left
        player_to_left_of self.current_player
      end

      def every_other_player
        @players.select { |player| player != current_player }
      end

      def pot
        @game.current_gambit.pot
      end
      alias :stakes :pot
      
      def weakest_flight_wins!
        class << @game.current_gambit
          def determine_winner
            @controller.players.min { |a, b| a.flight.strength <=> b.flight.strength }
          end
        end
      end

      def current_player_leads_next_round!
        index = @players.index self.current_player
        (class << @game.current_gambit.current_round; self; end).class_eval do
          define_method :highest_card do
            @gambit.controller.log "player at #{index} is #{@gambit.controller.players[index]}"
            index
          end
        end
      end

      def pay_gold(issuer, amt, destination)
        issuer = self.send(issuer.to_sym) unless issuer.is_a? TDA::Player
        self.send(destination.to_sym) << issuer.pay_gold(amt)
      end

      def take_gold(receiver, amt, source)
        receiver = self.send(receiver.to_sym) unless receiver.is_a? TDA::Player
        receiver.receive_gold(self.send(source.to_sym) >> amt)
      end

      def draw_cards(players, amt)
        players = self.send(players.to_sym)
        Array(players).each { |player| player.draw_card amt }
      end

      def discard_cards(player, amt)
        player = self.send(player.to_sym)
        amt = player.hand.length unless amt < player.hand.length
        amt.times do |i|
          player.show_hand_with_instruction "Select a card to discard"
          @game.deck.discard player.select_card(player.receive_input.to_i)
        end
      end

      def give_cards(from, amt, special, to)
        player = self.send(from.to_sym)
        to = self.send(to.to_sym)

        amt = player.hand.length unless amt < player.hand.length
        amt.times do |i|
          card_index = rand(player.hand.length-1) if special.include? "random"
          unless card_index
            player.show_hand_with_instruction "Select a card to give"
            card_index = player.receive_input.to_i
          end
          to.hand << player.select_card(card_index)
        end

        @game.broadcast "#{player.name} gives #{amt} cards to #{to.name}"
      end

      def give_chosen_cards(from, cards, to)
        player = self.send(from.to_sym)
        to = self.send(to.to_sym)
        cards.each do |card|
          to.hand << player.hand.delete(card)
          @game.broadcast "#{player.name} gives #{to.name} a #{card}"
        end
      end

      def method_missing(id, *args, &block)
        return give_chosen_cards($1, args, $2) if id.to_s =~ /^(\w+)_gives_chosen_cards_to_(\w+)$/
        return give_cards($1, $2.to_i, $3, $4) if id.to_s =~ /^(\w+)_gives_(\d+)(\w+)?_card_to_(\w+)$/
        return discard_cards($1, $2.to_i) if id.to_s =~ /^(\w+)_discards_(\d+)/
        return draw_cards($1, $2.to_i) if id.to_s =~ /^(\w+?)_draws_(\d+)/
        return pay_gold($1, $2.to_i, $3) if id.to_s =~ /^(\w+)_pays_(\d+)_gold_to_(\w+)$/
        return take_gold($1, $2.to_i, $3) if id.to_s =~ /^(\w+)_takes_(\d+)_gold_from_(\w+)$/

        return players_with_flight_of($1) if id.to_s =~ /^players_with_flight_of_(\w+)$/
        super
      end

    end

    #
    # Game Control
    #
    
    class History < Array
    end

    @game_begun = false
    attr_reader :deck, :api
    def begin
      return if @game_begun
      if @players.length < 1
        raise "No one's in the game!"
      end
      broadcast "Game begun!"
      
      @api = API.new(self)
      @history = History.new
      @deck = TDA::Deck.new
      all_players { |player| 
        player.receives_50_gold
        player.draws_6_cards
      }
      
      #@deck.stack_deck
      @game_begun = true
      until game_ends
        @current_gambit = Gambit.new(self)
        @history << @current_gambit.start
      end
      @game_begun = false
    end

    def game_ends
      @players.any? { |player| player.hoard <= 0 }
    end

    def current_player
      return nil unless @game_begun
      @current_gambit.current_round.current_player
    end

    class Ante < TDA::Card::SetOfCards
      def finalize!
        self.sort! { |a, b| b.strength <=> a.strength }
      end
    end

    class Pot
      def initialize
        @value = 0
      end

      def name
        "the pot"
      end

      def <<(amt)
        @value = @value + amt
      end

      def >>(amt)
        unless @value < amt
          @value = @value - amt
          return amt
        end

        # Oh no, where me Lucky Charms!
        @value = 0
        return @value - amt 
      end

      def empty?
        @value == 0
      end

      def to_s
        @value.to_s
      end

      def method_missing(id, *args, &block)
        @value.send(id, *args, &block)
      end
    end

    def request_ante
      all_players { |player| player.show_hand_with_instruction "Select ante from hand" }

      ante = Ante.new(@players.length)
      all_players_with_index { |player, index|
        ante[index] = player.select_card(player.receive_input.to_i)
      }
      ante
    end
    
    attr_reader :current_gambit
    class Gambit
      
      attr_reader :controller, :pot, :turn_order, :leader, :ante
      def initialize(controller)
        @controller = controller
        @pot = Pot.new
      end

      def start
        # Ante up
        @ante = @controller.request_ante
        ante_message = "Ante received:\r\n"
        @controller.all_players_with_index { |player, index|
          ante_message << " #{player.name} played #{@ante[index]}\r\n"
        }
        @controller.broadcast ante_message

        # TODO: Ante matches.
        @controller.log(@ante.join(', '))
        ante_leader = @ante.max { |a, b| a.strength <=> b.strength }
        gold_to_pay = ante_leader.strength
        @leader = @controller.players[ @ante.index(ante_leader) ]
        @ante.finalize!
        @controller.broadcast "#{@leader.name} is leader of this gambit."

        # Feed the pot
        @controller.players.each { |player| 
          player.send :"pays_#{gold_to_pay}_gold" 
          @pot << gold_to_pay
          player.start_flight
        }
        
        # Play Rounds
        @rounds = []
        leader = @ante.index ante_leader
        until gambit_ends
          @controller.broadcast "Round #{@rounds.length+1}"
          @current_round = Round.new(self, leader)
          @rounds << @current_round.start
          leader = @rounds.last.highest_card
          @controller.broadcast "#{@controller.players[leader].name} leads the next round."
        end

        # Determine winner
        @winner = determine_winner
        @controller.broadcast "#{@winner.name} wins the gambit."

        # End Gambit
        @winner.send :"receives_#{@pot}_gold"
        @ante.each { |card| @controller.deck.discard card }
        @controller.all_players { |player|
          player.flight.each { |card| @controller.deck.discard card }
          player.draws_2_cards
        }

        self
      end

      # General Gambit Control
      #
      def determine_winner
        @controller.players.max { |a, b| a.flight.strength <=> b.flight.strength }
      end

      def gambit_ends
        @rounds.length >= 3 || @pot.empty?
        # TODO: Lots of other gambit_end conditions.
      end

      attr_reader :current_round
      class Round
        def initialize(gambit, leader)
          @gambit = gambit
          @leader = leader
          @cards_played = []

          @turn_order = (0..@gambit.controller.players.length-1).to_a
          @turn_order.unshift @turn_order.pop until @turn_order.first == leader

        end

        attr_reader :current_player
        def start
          @turn_order.each { |index|
            @current_player = @gambit.controller.players[index]
            @current_player.enqueue_message("Play a card!\r\n#{@current_player.hand}")
            @cards_played << @current_player.add_to_flight(@current_player.receive_input.to_i)
            @gambit.controller.log @cards_played
            if (@cards_played.length == 1 ||
                @cards_played[-2].strength >= @cards_played.last.strength)
              @gambit.controller.broadcast "Power triggers."
              @cards_played.last.trigger(@gambit.controller.api)
            end
          }

          self
        end

        def highest_card
          # If everyone tied, leader stays the same.
          return @leader if @cards_played.all? { |card| 
            card.strength == @cards_played.first.strength 
          }
          cards = @cards_played.sort { |a, b| b.strength <=> a.strength }
          while cards.length > 1 && cards[0].strength == cards[1].strength
            highest = cards[0]
            cards.reject! { |card| card.strength == cards[0].strength }
          end
          cards.empty? ? @leader : @turn_order[@cards_played.index(cards.first)]
        end
      end
    end

  end
end

game = TDA::Game.new

loop do
  game.begin if game.players.length == 3
  break if game.stopped?
end

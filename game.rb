require 'gserver'
require 'cards'
require 'player'

module TDA
  class TDAServer < GServer

    PLAYER_CAP = 6

    #
    # Server Stuff
    #

    def initialize
      super(10001, DEFAULT_HOST, PLAYER_CAP)
      self.audit = true
      @players = []
    end

    def serve(io)
      io.print("Welcome to TDA! What's your name? ")
      begin
        player = Player.new(io.gets.strip.gsub(/\W/,''), self)
        add_player player
        success = true
      rescue Exception => e
        log e.message
        success = false
      end
      if success
        prompt = '> '
        io.print prompt
        prompted = true

        loop do
          if IO.select([io], nil, nil, 0.5)
            player.receive_input = io.gets.chop
            prompted = false
          elsif player.message_pending?
            io.puts "\r" if prompted
            io.puts "#{player.dequeue_message}\r"
            io.print prompt
            prompted = true
          end
        end
      end
    end

    def log(msg)
      super(msg)
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
    # Game Control
    #
    
    class History < Array
    end

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

    @game_begun = false
    attr_reader :deck
    def begin_game
      return if @game_begun
      if @players.length < 1
        raise "No one's in the game!"
      end
      broadcast "Game begun!"
      
      @history = History.new
      @deck = Deck.new
      all_players { |player| 
        player.receives_50_gold
        player.draws_6_cards
      }
      
      @game_begun = true
      @history << @current_gambit = Gambit.new(self) until @players.any? { |player| player.hoard <= 0 }
    end

    def request_ante
      all_players { |player| player.enqueue_message "Select ante from hand (#{player.hand.length}):\r\n#{player.hand}" }

      ante = Array.new(@players.length)
      all_players_with_index { |player, index|
        ante[index] = player.select_card(player.receive_input.to_i)
      }
      ante
    end
    
    attr_reader :current_gambit
    class Gambit
      
      attr_reader :controller, :pot, :turn_order, :leader
      def initialize(controller)
        @controller = controller
        @pot = 0
      
        # Ante up
        @ante = @controller.request_ante
        ante_message = "Ante received:\r\n"
        @controller.all_players_with_index { |player, index|
          ante_message << " #{player.name} played #{@ante[index]}\r\n"
        }
        @controller.broadcast ante_message
        # TODO: Ante matches.
        ante_leader = @ante.max { |a, b| a.strength <=> b.strength }
        gold_to_pay = ante_leader.strength
        @leader = @controller.players[ @ante.index(ante_leader) ]
        @controller.broadcast "#{@leader.name} is leader of this gambit."

        # Feed the pot
        @controller.players.each { |player| 
          player.send :"pays_#{gold_to_pay}_gold" 
          @pot = @pot + gold_to_pay
          player.start_flight
        }
        
        # Play Rounds
        @rounds = []
        leader = @ante.index ante_leader
        until gambit_ends
          @controller.broadcast "Round #{@rounds.length+1}"
          @rounds << Round.new(self, leader)
          leader = @rounds.last.highest_card
          @controller.broadcast "#{@controller.players[leader].name} leads the next round."
        end

        # Determine winner
        @winner = @controller.players.max { |a, b| a.flight.strength <=> b.flight.strength }
        @controller.broadcast "#{@winner.name} wins the gambit."

        # End Gambit
        @winner.send :"receives_#{@pot}_gold"
        @ante.each { |card| @controller.deck.discard card }
        @controller.all_players { |player|
          player.flight.each { |card| @controller.deck.discard card }
          player.draws_2_cards
        }
      end

      def gambit_ends
        @rounds.length >= 3 || @pot == 0
        # TODO: Lots of other gambit_end conditions.
      end
      
      class Round
        def initialize(gambit, leader)
          @gambit = gambit
          @leader = leader
          @cards_played = []

          @turn_order = (0..@gambit.controller.players.length-1).to_a
          @turn_order.unshift @turn_order.pop until @turn_order.first == leader

          @turn_order.each { |index|
            player = @gambit.controller.players[index]
            player.enqueue_message("Play a card!\r\n#{player.hand}")
            @cards_played << player.add_to_flight
            if @cards_played.length == 1 || @cards_played[-2].strength > @cards_played.last.strength
              @cards_played.last.trigger(@gambit.controller)
              @gambit.controller.broadcast "Power triggers."
            end
          }
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

server = TDA::TDAServer.new.start

loop do
  server.begin_game if server.players.length == 3
  break if server.stopped?
end

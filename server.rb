require 'gserver'

module TDA

  class Server < GServer
    def initialize(game, player_cap)
      super(10001, DEFAULT_HOST, player_cap)
      self.audit = true
      @game = game
    end

    def serve(io)
      io.print("Welcome to TDA! What's your name? ")
      begin
        player = Player.new(io.gets.strip.gsub(/\W/,''), @game)
        @game.add_player player
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

  end
end

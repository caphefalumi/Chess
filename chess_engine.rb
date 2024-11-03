require 'rubygems'
require 'ruby2d'


class Generate_moves
  
end
class Engine
  attr_reader :game

  def initialize(game)
    @game = game
    pawn_value = 1
    knight_value = 3
    bishop_value = 3
    rook_value = 5
    queen_value = 9
  end

  private def evaluate

  end
  # Generates a random legal move for black
  def random
    black_pieces = game.pieces.select { |p| p.color == @game.current_turn.to_s.capitalize }
    return if black_pieces.empty?

    # Select a random black piece
    piece_to_move = black_pieces.sample
    piece_to_move.generate_moves

    # Get the current position of the piece
    current_x, current_y = piece_to_move.position

    # Continue sampling until a piece with available moves is found
    while piece_to_move.moves.empty? || !piece_to_move.moves.sample[0].between?(0, 7) || !piece_to_move.moves.sample[1].between?(0, 7) || (piece_to_move.moves.sample[0] == current_x && piece_to_move.moves.sample[1] == current_y)
      piece_to_move = black_pieces.sample
      piece_to_move.generate_moves
    end

    # Create a new thread for the delay
    Thread.new do
      sleep(1)  # Wait for 1 second
      # Store the piece and move
      @game.clear_previous_selection(only_moves: false)
      @game.clicked_piece = piece_to_move
      move = piece_to_move.moves.sample
      if @game.clicked_piece
        @game.highlight_selected_piece(@game.clicked_piece.x, @game.clicked_piece.y)
        @game.move_piece_or_capture(move[0], move[1])

        # Switch turns to white after AI move
        @game.current_turn = :white
      end
    end
  end
end

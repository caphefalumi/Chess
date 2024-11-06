require 'rubygems'
require 'ruby2d'
require_relative 'eval_table'

class Generate_moves
  
end
class Engine

  def initialize(board)
    @board = board
    @black_score = 0 
    @white_score = 0  
  end

  def position_value(piece)
    
    position = piece.file * 8 + piece.rank
    # puts "#{piece.rank} #{piece.rank}"
    table = case piece.type
            when "Pawn"
              PAWN_TABLE[position]
            when "Knight"
              KNIGHTS_TABLE[position]
            when "Bishop"
              BISHOPS_TABLE[position]
            when "Rook"
              ROOKS_TABLE[position]
            when "Queen"
              QUEENS_TABLE[position]
            when "King"
              KINGS_TABLE[position]
            else
              0
            end
    return table
  end
  def evaluate
  
    @board.pieces.each do |piece|

      if piece.color == "White"
        @white_score += piece.get_value + position_value(piece)
      else
        @black_score += piece.get_value + position_value(piece)
      end
    end
  end
  

  def test 
    evaluate
    puts @white_score
    puts @black_score
  end
  def minimax(node, depth, maximizing_player)
    
  end
  # Generates a random legal move for black
  def random
    black_pieces = @board.pieces.select { |p| p.color == @board.current_turn.to_s.capitalize }
    return if black_pieces.empty?

    # Select a random black piece
    piece_to_move = black_pieces.sample
    piece_to_move.generate_moves

    # Get the current position of the piece
    current_x, current_y = piece_to_move.position

    # Continue sampling until a piece with available moves is found
    while piece_to_move.moves.to_a.empty? || !piece_to_move.moves.to_a.sample[0].between?(0, 7) || !piece_to_move.moves.to_a.sample[1].between?(0, 7) || (piece_to_move.moves.to_a.sample[0] == current_x && piece_to_move.moves.to_a.sample[1] == current_y)
      piece_to_move = black_pieces.sample
      piece_to_move.generate_moves
    end

    # Create a new thread for the delay
    Thread.new do
      sleep(rand(0.1..1))  # Wait for 1 second
      # Store the piece and move
      @board.clear_previous_selection(only_moves: false)
      @board.clicked_piece = piece_to_move
      move = piece_to_move.moves.to_a.sample
      if @board.clicked_piece
        @board.highlight_selected_piece(@board.clicked_piece.x, @board.clicked_piece.y)
        @board.make_move(move[0], move[1])

        # Switch turns to white after AI move
        @board.current_turn = :white
      end
    end
  end
end
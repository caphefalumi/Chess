require_relative 'eval_table'


class Engine

  def initialize(board)
    @board = board
    @max_depth = 2
    @black_score = 0 
    @white_score = 0  
  end

  private def position_value(piece)
    
    rank = piece.color == "Black" ? 7 - piece.rank : piece.rank
    position = piece.file * 8 + rank
    # puts "#{piece.rank} #{piece.rank}"
    table = case piece.type
            when "Pawn" then PAWN_TABLE
            when "Knight" then KNIGHTS_TABLE
            when "Bishop" then BISHOPS_TABLE
            when "Rook" then ROOKS_TABLE
            when "Queen" then QUEENS_TABLE
            when "King" then KINGS_TABLE
            end
    return table[position]
  end
  
  private def evaluate(maximizing_color)
    black_score = 0 
    white_score = 0  
    @board.pieces.each do |piece|
      if piece.color == "White"
        white_score += piece.get_value
      else
        black_score += piece.get_value
      end
    end
    evaluation = white_score - black_score
    perspective = maximizing_color == "White" ? 1 : -1
    return evaluation * perspective
  end
  

  def test
    
    # Execute the best move found
    Thread.new do
      sleep(0.1)
      if best_piece && best_move
        @board.clear_previous_selection(only_moves: false)
        @board.clicked_piece = best_piece
        @board.highlight_selected_piece(best_piece.x, best_piece.y)
        @board.make_move(best_move[0], best_move[1], true)
      end
    end
  end


  private def minimax_eval(depth, maximizing_player, maximizing_color)
    # Base case: if we've reached max depth or game over
    if depth == 0 || @board.game_over
      evaluation = evaluate(maximizing_color)
      return [nil, evaluation]
    end
  
    # Get all legal moves for the current position
    legal_moves = @board.get_moves
    legal_moves.each do |move|
      puts "Piece: #{move[:piece]}, From: #{move[:from]}, To: #{move[:to]}"
    end
    if maximizing_player
      max_eval = -Float::INFINITY
      best_move = nil
  
      legal_moves.each do |move_data|
        piece = @board.pieces.find { |p| p.name == move_data[:piece] && p.position == move_data[:from] }
        
        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(piece, target_pos[0], target_pos[1], false)
          
          # Recursive evaluation
          current_eval = minimax_eval(depth - 1, false, maximizing_color, alpha, beta)[1]
          
          # Unmake move
          @board.unmake_move(false)
          
          # Update best move if needed
          if current_eval > max_eval
            max_eval = current_eval
            best_move = [piece, target_pos]
          end
          
        end
      end
      
      return [best_move, max_eval]
    else
      min_eval = Float::INFINITY
      best_move = nil
      
      legal_moves.each do |move_data|
        piece = @board.pieces.find { |p| p.name == move_data[:piece] && 
                                       p.rank == move_data[:from][0] && 
                                       p.file == move_data[:from][1] }
        
        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(piece, target_pos[0], target_pos[1], false)
          
          # Recursive evaluation
          current_eval = minimax_eval(depth - 1, true, maximizing_color, alpha, beta)[1]
          
          # Unmake move
          @board.unmake_move(false)
          
          # Update best move if needed
          if current_eval < min_eval
            min_eval = current_eval
            best_move = [piece, target_pos]
          end
        end
      end
      
      return [best_move, min_eval]
    end
  end
  def minimax
    maximizing_color = @board.current_turn
    best_move = minimax_eval(@max_depth, true, maximizing_color)[0]
    puts best_move 
    # if best_move
    #   piece, target_pos = best_move
    #   Thread.new do
    #     sleep(0.5)  # Add a small delay for better visualization
    #     @board.clear_previous_selection(only_moves: false)
    #     @board.clicked_piece = piece
    #     @board.highlight_selected_piece(piece.x, piece.y)
    #     @board.make_move(target_pos[0], target_pos[1], true)
    #   end
    # end
  end

  # Generates a random legal move for black
  public def random
    pieces = @board.pieces.select { |p| p.color == @board.current_turn}
    return if pieces.empty?

    # Select a random black piece
    piece_to_move = pieces.sample
    piece_to_move.generate_moves

    # Get the current position of the piece
    current_x, current_y = piece_to_move.position
    king = @board.pieces.find { |p| p.type == "King" && p.color == @board.current_turn}
    # Continue sampling until a piece with available moves is found
    while piece_to_move.moves.to_a.empty? || !piece_to_move.moves.to_a.sample[0].between?(0, 7) || !piece_to_move.moves.to_a.sample[1].between?(0, 7) || (piece_to_move.moves.to_a.sample[0] == current_x && piece_to_move.moves.to_a.sample[1] == current_y)
      piece_to_move = pieces.sample
      piece_to_move.generate_moves
      if @board.checked
        @board.handle_check(piece_to_move, king)
      else
        @board.handle_pin(piece_to_move, king)
      end
    end

    # Create a new thread for the delay
    Thread.new do
      sleep(rand(1..1))  # Wait for 1 second
      # Store the piece and move
      @board.clear_previous_selection(only_moves: false)
      @board.clicked_piece = piece_to_move
      move = piece_to_move.moves.to_a.sample
      if @board.clicked_piece
        
        @board.highlight_selected_piece(@board.clicked_piece.x, @board.clicked_piece.y)
        @board.make_move(move[0], move[1])
        # Switch turns to white after AI move
      end
    end
  end
end
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
  

  def minimax
    # Store all possible moves and their evaluated scores
    best_score = -Float::INFINITY
    best_piece = nil
    best_move = nil
    
    # Get all pieces of current color
    current_pieces = @board.pieces.select { |p| p.color == @board.current_turn}
    
    # Evaluate each possible move
    current_pieces.each do |piece|
      piece.generate_moves
      
      piece.moves.each do |move|
        # Make temporary move
        temp_state = make_temp_move(piece, move)
        
        # Evaluate position after move
        score = minimax_eval(@max_depth - 1, false)
        
        # Undo temporary move
        undo_temp_move(piece, temp_state)
        
        # Update best move if better score found
        if score > best_score
          best_score = score
          best_piece = piece
          best_move = move
        end
      end
    end

    # Execute the best move found
    Thread.new do
      sleep(0.1)
      if best_piece && best_move
        @board.clear_previous_selection(only_moves: false)
        @board.clicked_piece = best_piece
        @board.highlight_selected_piece(best_piece.x, best_piece.y)
        @board.make_move(best_move[0], best_move[1])
      end
    end
  end

  private

  def minimax_eval(depth, is_maximizing)
    # Base case: if we've reached max depth or game over
    if depth == 0 || @board.game_over

    end

    current_pieces = @board.pieces.select { |p| p.color == (is_maximizing ? "White" : "Black") }
    current_tmp_pieces = current_pieces.dup
    if is_maximizing
      max_eval = -Float::INFINITY
      
      current_tmp_pieces.each do |piece|
        piece.generate_moves
        piece.moves.each do |move|
          temp_state = make_temp_move(piece, move)
          eval = minimax_eval(depth - 1, false)
          undo_temp_move(piece, temp_state)
          max_eval = [max_eval, eval].max
        end
      end
      
      return max_eval
    else
      min_eval = Float::INFINITY
      
      current_tmp_pieces.each do |piece|
        piece.generate_moves
        piece.moves.each do |move|
          temp_state = make_temp_move(piece, move)
          eval = minimax_eval(depth - 1, true)
          undo_temp_move(piece, temp_state)
          min_eval = [min_eval, eval].min
        end
      end
      
      return min_eval
    end
  end

  def evaluate_position
    score = 0
    
    @board.pieces.each do |piece|
      # Basic material evaluation
      value = piece.get_value
      multiplier = piece.color == "White" ? -1 : 1  # Reversed since black is maximizing
      score += value * multiplier
      
      # Simple positional bonuses
      case piece.type
      when "Pawn"
        # Encourage pawn advancement
        advance_bonus = piece.color == "Black" ? piece.file : (7 - piece.file)
        score += advance_bonus * multiplier
      when "Knight", "Bishop"
        # Encourage piece development
        if piece.is_moved
          score += 10 * multiplier
        end
      end
    end
    
    score
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
      sleep(1)  # Wait for 1 second
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
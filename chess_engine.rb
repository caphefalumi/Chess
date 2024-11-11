require_relative 'eval_table'

class Engine
  def initialize(board)
    @board = board
    @max_depth = 2
  end

  # Evaluates the current board state
  def evaluate(maximizing_color)
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

  # Minimax algorithm with alpha-beta pruning
  private def minimax_eval(depth, maximizing_player, maximizing_color, alpha = -Float::INFINITY, beta = Float::INFINITY)
    # Base case: check for max depth or game over state
    if depth == 0 || @board.game_over
      evaluation = evaluate(maximizing_color)
      return [nil, evaluation]
    end

    legal_moves = @board.get_moves
    best_move = nil

    if maximizing_player
      max_eval = -Float::INFINITY

      legal_moves.each do |move_data|
        piece = @board.pieces.find { |p| p.name == move_data[:piece] && p.position == move_data[:from] }

        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(piece, target_pos[0], target_pos[1])

          # Recursive evaluation
          _, current_eval = minimax_eval(depth - 1, false, maximizing_color, alpha, beta)

          # Unmake move
          @board.unmake_move()

          # Update the best move if the current evaluation is better
          if current_eval > max_eval
            max_eval = current_eval
            best_move = [piece, target_pos]
          end

          alpha = [alpha, current_eval].max
          break if beta <= alpha # Alpha-beta pruning
        end
      end

      return [best_move, max_eval]
    else
      min_eval = Float::INFINITY

      legal_moves.each do |move_data|
        piece = @board.pieces.find { |p| p.name == move_data[:piece] && p.position == move_data[:from] }

        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(piece, target_pos[0], target_pos[1])

          # Recursive evaluation
          _, current_eval = minimax_eval(depth - 1, true, maximizing_color, alpha, beta)

          # Unmake move
          @board.unmake_move(false)

          # Update the best move if the current evaluation is better
          if current_eval < min_eval
            min_eval = current_eval
            best_move = [piece, target_pos]
          end

          beta = [beta, current_eval].min
          break if beta <= alpha # Alpha-beta pruning
        end
      end

      return [best_move, min_eval]
    end
  end

  # Finds and executes the best move using Minimax
  def minimax
    maximizing_color = @board.current_turn
    best_move, _ = minimax_eval(@max_depth, true, maximizing_color)

    if best_move
      piece, target_pos = best_move
      puts "Best move: #{piece.name} to #{target_pos}"
      
      # Execute the best move
      Thread.new do
        sleep(0.1)
        @board.clear_previous_selection(only_moves: false)
        @board.clicked_piece = piece
        @board.highlight_selected_piece(piece.x, piece.y)
        @board.make_move(target_pos[0], target_pos[1])
      end
    end
  end

  # Generates a random move for the current player
  def random
    pieces = @board.pieces.select { |p| p.color == @board.current_turn }
    return if pieces.empty?
    legal_moves = @board.get_moves

    random_piece = legal_moves.sample
    moves = random_piece[:to].to_a.sample
    
    # Execute random move
    Thread.new do
      sleep(0.5)
      @board.clear_previous_selection(only_moves: false)
      if moves
        puts evaluate("White")
        @board.highlight_selected_piece(moves[0]*80, moves[1]*80)
        @board.make_move(random_piece[:piece], moves[0], moves[1])
      end
    end
  end
end

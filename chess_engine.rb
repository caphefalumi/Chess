require_relative 'eval_table'

class Engine
  def initialize(board)
    @board = board
    @max_depth = 2
    @best_move = nil
  end

  # Evaluates the current board state
  def evaluate(maximizing_player)
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
    perspective = maximizing_player == true ? -1 : 1
    return evaluation * perspective
  end

  # Minimax algorithm with alpha-beta pruning
  private def minimax_eval(legal_moves, depth, maximizing_player, alpha = -Float::INFINITY, beta = Float::INFINITY)
    # Base case: check for max depth or game over state
    if depth == 0 || @board.game_over
      return evaluate(maximizing_player)
    end

    if maximizing_player
      max_eval = -Float::INFINITY

      legal_moves.each do |move_data|

        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(move_data[:piece], target_pos[0], target_pos[1])
          next_moves = @board.get_moves
          # Recursive evaluation
          score = minimax_eval(next_moves, depth - 1, false , alpha, beta)

          if score > max_eval
            max_eval = score
            if depth == @max_depth
              @best_move = [move_data[:piece], target_pos]
            end
          end
          @board.unmake_move
          # Unmake move

          alpha = [alpha, score].max
          break if beta <= alpha # Alpha-beta pruning
        end
      end

      return max_eval

    else
      min_eval = Float::INFINITY

      legal_moves.each do |move_data|

        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(move_data[:piece], target_pos[0], target_pos[1])
          next_moves = @board.get_moves
          # Recursive evaluation
          score = minimax_eval(next_moves, depth - 1, true, alpha, beta)

          if score < min_eval
            min_eval = score
            if depth == @max_depth
              @best_move = [move_data[:piece], target_pos]
            end
          end
          @board.unmake_move

          beta = [beta, score].min
          break if beta <= alpha # Alpha-beta pruning
        end
      end

      return min_eval
    end
  end

  # Finds and executes the best move using Minimax
  def minimax
    @best_move = nil
    @board.player_playing = false
    moves = @board.get_moves
    @board.render = false
    minimax_eval(moves, @max_depth, true)
    @board.render = true
    if @best_move
      piece, target_pos = @best_move
      puts "Best move: #{piece.name} to #{target_pos}"
      
      # Execute the best move
      @board.make_move(piece, target_pos[0], target_pos[1])
    end
  end

  def negamax_tree

  end

  def negamax
    
  end
  
  # Generates a random move for the current player
  def random
    legal_moves = @board.get_moves
    random_piece = legal_moves.sample
    moves = random_piece[:to].to_a.sample
    # Execute random move
    Thread.new do
      sleep(0.5)
      @board.clear_previous_selection(only_moves: false)
      if moves
        @board.make_move(random_piece[:piece], moves[0], moves[1])
      end
    end

  end
end

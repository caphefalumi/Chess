require_relative 'eval_table'

class Engine
  def initialize(board)
    @board = board
    @best_move = nil
    @max_depth = 2
    @node_travel = 0
    @move_travel = 0
  end

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
    perspective = maximizing_player ? -1 : 1
    return evaluation * perspective
  end

  private def minimax_eval(legal_moves, depth, maximizing_player, alpha = -Float::INFINITY, beta = Float::INFINITY)
    # Base case: check for max depth or game over state
    if depth == 0 || @board.game_over
      return evaluate(maximizing_player)
    end
    @node_travel +=1
    break_signal = false
    if maximizing_player
      max_score = -Float::INFINITY

      legal_moves.each do |move_data|
        break if break_signal
        move_data[:to].each do |target_pos|
          @move_travel += 1
          # Make move
          @board.make_move(move_data[:piece], target_pos[0], target_pos[1])
          next_moves = @board.get_moves
          # Recursive evaluation
          score = minimax_eval(next_moves, depth - 1, false , alpha, beta)

          if score > max_score
            max_score = score
            if depth == @max_depth
              @best_move = [move_data[:piece], target_pos]
            end
          end
          
          if max_score > alpha
            alpha = max_score
          end

          if max_score >= beta
            @board.unmake_move
            break_signal = true
            break # Alpha-beta pruning
          end
          @board.unmake_move
        end
        
      end
      return max_score

    else
      min_score = Float::INFINITY

      legal_moves.each do |move_data|
        break if break_signal
        move_data[:to].each do |target_pos|
          # Make move
          @board.make_move(move_data[:piece], target_pos[0], target_pos[1])
          next_moves = @board.get_moves
          # Recursive evaluation
          score = minimax_eval(next_moves, depth - 1, true, alpha, beta)

          if score < min_score
            min_score = score
          end
          @board.unmake_move

          if min_score < beta
            beta = min_score
          end

          if min_score <= alpha
            break_signal = true
            break
          end
        end
      end

      return min_score
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
    puts @best_move
    if @best_move
      piece, target_pos = @best_move
      puts "Best move: #{piece.name} to #{target_pos}"
      puts "Total nodes search #{@node_travel}"
      puts "Total moves search #{@move_travel}"
      # Execute the best move
      @board.make_move(piece, target_pos[0], target_pos[1])
    end
  end


  def random
    legal_moves = @board.get_moves
    random_piece = legal_moves.sample
    moves = random_piece[:to].to_a.sample
    @board.clear_previous_selection(only_moves: false)
    if moves
      puts "Moving #{random_piece[:piece].name}"
      @board.make_move(random_piece[:piece], moves[0], moves[1])
    end
  end
end
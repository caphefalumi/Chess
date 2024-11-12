require_relative 'eval_table'

class Engine
  def initialize(board)
    @board = board
    @best_move = nil
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

  def brute_force
    @best_move = nil
    best_score = -Float::INFINITY
    move_count = 0
    
    @board.player_playing = false
    @board.render = false
  
    legal_moves = @board.get_moves
    
    # Debug output for initial legal moves
    legal_moves.each do |move_data|
      piece = move_data[:piece]
      puts "#{piece.color}#{piece.name} at [#{piece.rank}, #{piece.file}] can move to: #{move_data[:to].inspect}"
    end

    legal_moves.each do |move_data|
      current_piece = move_data[:piece]
      
      move_data[:to].each do |target_pos|
        # Validate move before attempting
        next unless valid_move?(current_piece, target_pos)
        
        move_count += 1
        
        # Debug output for each move being considered
        puts "Trying #{current_piece.color}#{current_piece.name} from [#{current_piece.rank}, #{current_piece.file}] to [#{target_pos[0]}, #{target_pos[1]}]"
        
        @board.make_move(current_piece, target_pos[0], target_pos[1])
        
        opponent_moves = @board.get_moves
        worst_score = Float::INFINITY
        
        opponent_moves.each do |opp_move|
          opp_piece = opp_move[:piece]
          
          opp_move[:to].each do |opp_target|
            # Validate opponent move before attempting
            next unless valid_move?(opp_piece, opp_target)
            
            @board.make_move(opp_piece, opp_target[0], opp_target[1])
            score = evaluate(true)
            worst_score = [worst_score, score].min
            @board.unmake_move
          end
        end
        
        @board.unmake_move
        
        if worst_score > best_score
          best_score = worst_score
          @best_move = [current_piece, target_pos]
          puts "New best move found: #{current_piece.color}#{current_piece.name} to [#{target_pos[0]}, #{target_pos[1]}]"
        end
      end
    end
  
    if @best_move
      @board.player_playing = true
      @board.render = true
      
      piece, target_pos = @best_move
      
      # Final validation before executing the move
      if valid_move?(piece, target_pos)
        puts "Executing move: #{piece.color}#{piece.name} from [#{piece.rank}, #{piece.file}] to [#{target_pos[0]}, #{target_pos[1]}]"
        puts "Evaluated #{move_count} possible positions"
        @board.make_move(piece, target_pos[0], target_pos[1])
      else
        puts "ERROR: Final selected move was invalid! Picking random move instead."
        random
      end
    end
  end

  def valid_move?(piece, target_pos)
    # Basic bounds checking
    return false if target_pos[0] < 0 || target_pos[0] > 7 || target_pos[1] < 0 || target_pos[1] > 7
    
    # Verify the move is in the piece's legal moves list
    return false unless piece.moves.include?([target_pos[0], target_pos[1]])
    
    # Verify the target square is either empty or contains an enemy piece
    target_piece = @board.pieces.find { |p| p.position == [target_pos[0], target_pos[1]] }
    return true if target_piece.nil?
    return target_piece.color != piece.color
  end

  def random
    legal_moves = @board.get_moves
    random_piece = legal_moves.sample
    moves = random_piece[:to].to_a.sample

    Thread.new do
      sleep(0.5)
      @board.clear_previous_selection(only_moves: false)
      if moves
        @board.make_move(random_piece[:piece], moves[0], moves[1])
      end
    end
  end
end
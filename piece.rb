require 'rubygems'
require 'ruby2d'
require 'set'
class Piece
  attr_accessor :x, :y, :piece, :bot, :position, :moves, :render, :king_color, :can_castle, :can_en_passant, :is_moved, :is_checked, :is_pinned, :attacking_pieces

  def initialize(x, y, piece, piece_image, game)
    @x, @y, @piece, @piece_image, @game = x, y, piece, piece_image, game
    @moves = []
    @blocking_squares = Set.new()
    @cached_moves = Set.new()
    @bot = false
    @attacking_pieces = Set.new()
    @king_color = "White"
    @is_moved = false
    @pinned_piece = nil
    @checked = false
    @can_en_passant = false
  end

  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y, z: ZOrder::PIECE, width: 80, height: 80)
  end

  def rank
    @x / 80
  end
  def file
    @y / 80
  end
  def position
    [@x, @y]
  end

  def name
    color + type if type != "No Piece"
  end

  def color
    (@piece & (0b01000 | 0b10000)) == 8 ? "White" : "Black"
  end

  def type
    case @piece & 0b00111
    when PieceEval::KING   then "King"
    when PieceEval::QUEEN  then "Queen"
    when PieceEval::ROOK   then "Rook"
    when PieceEval::BISHOP then "Bishop"
    when PieceEval::KNIGHT then "Knight"
    when PieceEval::PAWN   then "Pawn"
    else "None"
    end
  end

  def generate_moves()
    @moves.clear
    case type
    when "King"    then king_moves
    when "Queen", "Rook", "Bishop" then sliding_moves(type)
    when "Knight"  then knight_moves
    when "Pawn"    then pawn_moves
    end
    @moves = get_valid_moves if is_pinned?

  end

  def generate_attack_moves 
    if @king_color != color
      generate_moves
    end
  end
  def king_moves
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    directions.each do |dx,dy|
      add_move_if_legal(@x / 80 + dx, @y / 80 + dy) if !is_checked?(@x / 80 + dx, @y / 80 + dy)
    end

    #Castle
    if !is_moved
      king_side_rook = find_castling_rook(7 * 80)
      queen_side_rook = find_castling_rook(0)
      add_move_if_legal(6, @y / 80) if king_side_rook && no_pieces_between(king_side_rook)
      add_move_if_legal(2, @y / 80) if queen_side_rook && no_pieces_between(queen_side_rook)
    end
  end
  def is_checked?(dx = @x / 80, dy = @y / 80, p_color = color)
  
    king_position = [dx, dy]
    @checked = false  # Reset only if we don’t find any threats
  
    @game.pieces.each do |piece|
      next if piece.color == p_color || piece.type == "King" # Only consider opponent pieces
      generate_bot_moves(piece)
      
      if piece.moves.include?(king_position)
        @attacking_pieces.add(piece)
        @checked = true
      end
    end
    if @checked == false && @blocking_squares
      @blocking_squares.clear
    end
    return @checked  # Return the current status of @checked
  end

  def handle_check()
    moves_to_block = []
    squares_from_attack_to_king(@attacking_pieces.first) 
    blocking_squares = @blocking_squares.to_a
    if @attacking_pieces.size == 1 # Double check
    # Single check
      @game.pieces.each do |piece|
        next if piece.color != color
        puts piece.name
        piece.generate_moves()
        piece.moves.each do |move|
          if blocking_squares.include?(move)
            moves_to_block << move
            puts "#{piece.name} from #{[piece.rank, piece.file ]} to #{move}" 
          else 
            # puts "#{blocking_squares.inspect} #{piece.name}: #{move}"
          end
        end
      end
    elsif @attacking_pieces.size == 2 || moves_to_block.size == 0
      king_moves
    end
    puts moves_to_block.inspect
    return moves_to_block
  end


  # Function to calculate potential blocking squares between the king and the attacking piece
  def squares_from_attack_to_king(attacking_piece)
    
    # Special handling for knights - only the knight's position can be blocked
    if attacking_piece.type == "Knight" || attacking_piece.type == "Pawn"
      @blocking_squares.add([attacking_piece.x / 80, attacking_piece.y / 80])
      return
    end
    
    
    # For sliding pieces (Queen, Rook, Bishop), calculate path
    dx = attacking_piece.x - @x
    dy = attacking_piece.y - @y
    
    # Get the number of steps to normalize direction
    steps = [dx.abs, dy.abs].max
    return @blocking_squares if steps == 0
    
    # Normalize to get unit vector
    dx = (dx.to_f / steps).round
    dy = (dy.to_f / steps).round
    
    # Start from the square next to the king
    current_x = @x / 80 + dx
    current_y = @y / 80 + dy
    
    # Add all squares from king to attacking piece (inclusive)
    while current_x * 80 != attacking_piece.x + dx * 80 || current_y * 80 != attacking_piece.y + dy * 80
      @blocking_squares.add([current_x, current_y])
      current_x += dx
      current_y += dy
    end
    
  end



  def generate_bot_moves(piece)
    piece.bot = true
    piece.generate_attack_moves
    piece.bot = false
  end
  def find_castling_rook(file_position)
    @game.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == file_position }
  end

  def no_pieces_between(rook)
    king_file, rook_file = @x / 80, rook.x / 80
    range = (rook_file < king_file ? (rook_file + 1)...king_file : (king_file + 1)...rook_file)
    range.none? { |file| @game.pieces.find { |p| p.x == file * 80 && p.y == @y } }
  end

  def is_pinned?
    return false if type == "King"  # Kings cannot be pinned
    
    king = @game.pieces.find { |p| p.type == "King" && p.color == color }
    
    # Store original position
    original_x, original_y = @x, @y
    
    # Temporarily remove this piece from the board
    @game.pieces.delete(self)
    
    # Check if removing this piece puts the king in check
    is_pinned = king.is_checked?
    if is_pinned
      @pinned_piece = self
    end
    # Restore the piece
    @game.pieces << self
    @x, @y = original_x, original_y
    
    return is_pinned
  end

  def get_valid_moves    
    king = @game.pieces.find { |p| p.type == "King" && p.color == color }
    return @moves unless is_pinned?  # Return all moves if not pinned
    
    pin_line = []
    original_x, original_y = @x, @y
    original_moves = @moves.dup
    
    # Try each possible move
    original_moves.each do |move|
      # Temporarily move the piece
      @x, @y = move[0] * 80, move[1] * 80
      

      # Check if this move keeps the king safe
      if !king.is_checked?
        pin_line << [move[0], move[1]]
      end
      
      # Restore captured piece if any
      
      # Restore original position
      @x, @y = original_x, original_y
    end
    # Return only the moves that keep the king safe
    pin_line
  end


  def sliding_moves(type)
    directions = {
      "Rook"   => [[1, 0], [-1, 0], [0, 1], [0, -1]],
      "Bishop" => [[1, 1], [-1, -1], [1, -1], [-1, 1]],
      "Queen"  => [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    }
    
    directions[type].each do |dx, dy|
      x, y = @x / 80, @y / 80
      loop do
        x += dx
        y += dy
        break unless add_move_if_legal(x, y)
      end
    end
  end

  def knight_moves
    knight_offsets = [[2, 1], [2, -1], [-2, 1], [-2, -1], [1, 2], [1, -2], [-1, 2], [-1, -2]]
    knight_offsets.each do |dx, dy| 
      add_move_if_legal(@x / 80 + dx, @y / 80 + dy)
    end
  end

  def pawn_moves
    direction = color == "White" ? -1 : 1
    rank, file = @x / 80, @y / 80

    # Single step
    add_move_if_legal(rank, file + direction) if empty_square?(rank, file + direction) && !@bot

    # Double step from starting rank
    if (color == "White" && file == 6) || (color == "Black" && file == 1)
      add_move_if_legal(rank, file + 2 * direction) if empty_square?(rank, file + direction) && empty_square?(rank, file + 2 * direction) && !@bot
    end

    # Capture moves
    capture_pawn(rank - 1, file + direction)
    capture_pawn(rank + 1, file + direction)

    # En passant
    add_en_passant_moves(rank, file, direction)
  end

  def empty_square?(x, y)
    !@game.pieces.any? { |p| p.x == x * 80 && p.y == y * 80 }
  end

  def capture_pawn(target_rank, target_file)
    target_piece = @game.pieces.find { |p| p.x == target_rank * 80 && p.y == target_file * 80 }
    if (target_piece && target_piece.color != color) || @bot
      add_move_if_legal(target_rank, target_file) 
    end
  end

  def add_en_passant_moves(rank, file, direction)
    if @game.last_move&.type == "Pawn" && @game.last_move.can_en_passant
      en_passant_positions = [[rank - 1, file], [rank + 1, file]]
      en_passant_positions.each do |target_rank, _|
        add_move_if_legal(target_rank, file + direction) if @game.last_move.x == target_rank * 80 && @game.last_move.y == @y
      end
    end
  end

  def promotion(choice)
    piece_map = { "Queen" => PieceEval::QUEEN, "Rook" => PieceEval::ROOK, "Bishop" => PieceEval::BISHOP, "Knight" => PieceEval::KNIGHT }
    new_piece_type = piece_map[choice] || PieceEval::QUEEN
    promote(new_piece_type | (color == "White" ? PieceEval::WHITE : PieceEval::BLACK))
  end

  def promote(new_piece_type)
    @piece = new_piece_type
    @piece_image = piece_image(@piece)
    render_piece
    puts "#{color} pawn promoted to #{type}!"
  end

  def add_move_if_legal(new_x, new_y)
    return false unless new_x.between?(0, 7) && new_y.between?(0, 7)
    
    target_piece = @game.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80 && p.color }
    if target_piece.nil? || (target_piece.type == "King" && target_piece.color != color)
      @moves << [new_x, new_y]
      true
    elsif target_piece.color != color
      @moves << [new_x, new_y]
      false
    elsif target_piece.color == color && color == "Black" && @bot
      @moves << [new_x, new_y]
      true
    end
    
  end
end

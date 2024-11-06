require 'set'




class Piece
  attr_reader :piece, :position, :render
  attr_accessor :x, :y, :pre_x, :pre_y, :bot, :moves, :can_castle, :can_en_passant, :capture_piece, :attacking_pieces, :is_pinned, :is_moved, :is_checked

  def initialize(x, y, piece, piece_image, board)
    @x, @y, @piece, @piece_image, @board = x, y, piece, piece_image, board
    @moves = Set.new()
    @bot = false
    @attacking_pieces = Set.new()
    @king_color = "White"
    @is_moved = false
    @is_pinned = false
    @is_checked = false
    @can_en_passant = false
  end

  def render_piece
    @render = Image.new(
      @piece_image,
      x: @x,
      y: @y,
      z: ZOrder::PIECE,
      width: 80,
      height: 80
    )
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
    end
  end

  def get_value
    case type
      when "King" then 10000
      when "Queen" then 929
      when "Rook" then 479
      when "Bishop" then 320
      when "Knight" then 280
      when "Pawn" then 100
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

    if !is_moved
      king_side_rook = find_castling_rook(7 * 80)
      queen_side_rook = find_castling_rook(0)
      add_move_if_legal(6, @y / 80) if king_side_rook && no_pieces_between(king_side_rook)
      add_move_if_legal(2, @y / 80) if queen_side_rook && no_pieces_between(queen_side_rook)
    end
  end

  def find_castling_rook(file_position)
    @board.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == file_position }
  end

  def no_pieces_between(rook)
    king_file, rook_file = @x / 80, rook.x / 80
    range = (rook_file < king_file ? (rook_file + 1)...king_file : (king_file + 1)...rook_file)
    range.none? { |file| @board.pieces.find { |p| p.x == file * 80 && p.y == @y} }
  end

  def is_checked?(rank = @x / 80, file = @y / 80)
  
    king_position = [rank, file]
    @is_checked = false  # Reset only if we don’t find any threats
    @board.pieces.each do |piece|
      next if piece.color == color || piece.type == "King" # Only consider opponent pieces
      generate_bot_moves(piece)
      
      if piece.moves.include?(king_position)
        @attacking_pieces.add(piece)
        @is_checked = true
        break  # Exit early since we found a check
      end
    end
    return @is_checked  # Return the current status of @checked
  end
  
  def handle_check(piece)
    attacking_piece = @attacking_pieces.first
    legal_moves = Set.new()
    blocking_squares = calculate_blocking_squares(attacking_piece) 
    legal_moves.add([attacking_piece.rank, attacking_piece.file])
    if @attacking_pieces.size == 2 # Double check or more
      king_moves  # Force the king to move
    elsif blocking_squares.any?  # Single check
      piece.moves.each do |move|
        if piece.type == "Pawn"
        end
        if blocking_squares.include?(move)
          legal_moves.add(move)
        end
      end
    end
    return legal_moves.to_a
  end

  def is_pinned?
    return if type == "King"
    king = @board.pieces.find { |p| p.type == "King" && p.color == color && p.is_checked == false}
    if king 
      @board.pieces.delete(self)
      if king.is_checked?()
        @board.valid_moves = king.handle_check(self)
        @is_pinned = true
      else
        @is_pinned = false
      end
    end
    @board.pieces.add(self)

  end
  # Function to calculate potential blocking squares between the king and the attacking piece
  def calculate_blocking_squares(attacking_piece)
    blocking_squares = Set.new
  
    # Calculate the direction of the attack (dx and dy represent the unit step in each direction)
    dx = (attacking_piece.x - @x) / 80
    dy = (attacking_piece.y - @y) / 80
  
    # Ensure dx and dy are either -1, 0, or 1 to capture vertical, horizontal, or diagonal directions
    dx = dx <=> 0
    dy = dy <=> 0
  
    # Calculate intermediate squares between king and attacking piece, including up to the attacking piece's position
    x, y = @x + dx * 80, @y + dy * 80
    count = 0
    if attacking_piece.type != "Knight"
      while [x, y] != [attacking_piece.x + dx * 80, attacking_piece.y + dy * 80]
        if count == 10
          break
        end
        blocking_squares.add([x / 80, y / 80])
        x += dx * 80
        y += dy * 80
        count += 1
      end
    end
  
    return blocking_squares.to_a
  end
  
  def generate_bot_moves(piece)
    piece.bot = true
    piece.generate_attack_moves
    piece.bot = false
  end


  private def sliding_moves(type)
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

  private def knight_moves
    knight_offsets = [[2, 1], [2, -1], [-2, 1], [-2, -1], [1, 2], [1, -2], [-1, 2], [-1, -2]]
    knight_offsets.each do |dx, dy| 
      add_move_if_legal(@x / 80 + dx, @y / 80 + dy)
    end
  end

  private def pawn_moves
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

  private def empty_square?(x, y)
    !@board.pieces.find { |p| p.x == x * 80 && p.y == y * 80 }
  end

  private def capture_pawn(target_rank, target_file)
    target_piece = @board.pieces.find { |p| p.x == target_rank * 80 && p.y == target_file * 80 }
    if (target_piece && target_piece.color != color) || @bot
      add_move_if_legal(target_rank, target_file) 
    end
  end

  private def add_en_passant_moves(rank, file, direction)
    if @board.last_move&.type == "Pawn" && @board.last_move.can_en_passant
      en_passant_positions = [[rank - 1, file], [rank + 1, file]]
      en_passant_positions.each do |target_rank, _|
        add_move_if_legal(target_rank, file + direction) if @board.last_move.x == target_rank * 80 && @board.last_move.y == @y
      end
    end
  end

  def promotion(choice)
    piece_map = { "Queen" => PieceEval::QUEEN, "Rook" => PieceEval::ROOK, "Bishop" => PieceEval::BISHOP, "Night" => PieceEval::KNIGHT }
    new_piece_type = piece_map[choice] || PieceEval::QUEEN
    promote(new_piece_type | (color == "White" ? PieceEval::WHITE : PieceEval::BLACK))
  end

  private def promote(new_piece_type)
    @piece = new_piece_type
    @piece_image = piece_image(@piece)
    render_piece
    puts "#{color} promoted to #{type}!"
  end

  private def add_move_if_legal(new_x, new_y)
    return false unless new_x.between?(0, 7) && new_y.between?(0, 7)
    
    target_piece = @board.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80}
    # Empty square or perform a xray attack  
    if target_piece.nil? || (target_piece.type == "King" && target_piece.color != color)
      @moves.add([new_x, new_y])
      true
    # Capture a piece
    elsif target_piece.color != color
      @moves.add([new_x, new_y])
      false
    # Protect a friendly piece
    elsif target_piece.color == color && color == "Black" && @bot
      @moves.add([new_x, new_y])
      false
    end
    
  end
end

require 'set'




class Piece
  attr_reader :piece, :render, :promoted, :blocking_squares
  attr_accessor :x, :y, :pre_x, :pre_y, :bot, :moves, :can_en_passant, :captured_pieces, :promoted, :attacking_pieces, :is_pinned, :is_moved, :is_checked

  def initialize(x, y, piece, board)
    @x, @y, @piece, @board = x, y, piece, board
    @attacking_pieces = Set.new()
    @moves = Array.new()
    @pre_x = Array.new()
    @pre_y = Array.new()
    @captured_pieces = Array.new()
    @promoted = [0, false]
    @bot = false
    @is_moved = false
    @is_pinned = false
    @is_checked = false
    @can_en_passant = false
    @generating_moves = false
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
    color + type
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
    when PieceEval::KNIGHT then "Night"
    when PieceEval::PAWN   then "Pawn"
    end
  end
  
  def piece_image(piece_type)
    return "pieces/#{color[0]}#{piece_type[0]}.png"
  end

  def render_piece
    @render = Image.new(
      piece_image(type[0]),
      x: @x,
      y: @y,
      z: ZOrder::PIECE,
      width: 80,
      height: 80
    )
  end

  def get_value
    case type
    when "King" then 10000
    when "Queen" then 1000
    when "Rook" then 500
    when "Bishop" then 350
    when "Night" then 300
    when "Pawn" then 100
    end
  end

  
  def generate_moves()
    @moves.clear
    case type
    when "King"    then king_moves
    when "Queen", "Rook", "Bishop" then sliding_moves(type)
    when "Night"  then knight_moves
    when "Pawn"    then pawn_moves
    end
  end

  def generate_attack_moves 
    king_color = @board.pieces.find { |p| p.type == "King" && p.color == @current_turn }
    if king_color != color
      generate_moves
    end
  end

  def king_moves
    @generating_moves = true
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    directions.each do |dx,dy|
      add_move_if_legal(rank + dx, file + dy) if !is_checked?(rank + dx, file + dy)
    end
    if !is_moved && !@board.checked
      king_side_rook = find_castling_rook(7 * 80)
      queen_side_rook = find_castling_rook(0)
      add_move_if_legal(6, file) if king_side_rook && no_pieces_between(king_side_rook) && !is_checked?(6, file)
      add_move_if_legal(2, file) if queen_side_rook && no_pieces_between(queen_side_rook) && !is_checked?(2, file)
    end
    @generating_moves = false
  end

  private def find_castling_rook(file_position)
    @board.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == file_position }
  end

  private def no_pieces_between(rook)
    king_file = @x / 80
    rook_file = rook.x / 80
  
    # Determine the range of files to check between King and Rook
    files_between = (king_file < rook_file) ? (king_file + 1...rook_file) : (rook_file + 1...king_file)
  
    # Check if any pieces exist in the specified range on the same rank (@y)
    files_between.each do |file|
      return false if @board.pieces.any? { |piece| piece.x == file * 80 && piece.y == @y }
    end
  
    true
  end
  

  def is_checked?(rank = @x / 80, file = @y / 80)
    king_position = [rank, file]
    @is_checked = false
  
    @board.pieces.each do |piece|
      next if piece.color == color # Only consider opponent pieces
  
      # Special case for opponent King: check adjacent squares
      if piece.type == "King"
        if (piece.rank - rank).abs <= 1 && (piece.file - file).abs <= 1
          @is_checked = true
          break
        end
        next
      end
  
      generate_bot_moves(piece)
      if piece.moves.include?(king_position)
        if piece.type == "Pawn" && piece.rank == king_position[0]
          @is_checked = false
        else
          @attacking_pieces.add(piece) if !@generating_moves
          @is_checked = true
          break if @attacking_pieces.size == 2 # Optimization: Stop if two attackers are found
        end
      end
    end
    return @is_checked
  end
  

  def is_pinned?
    return false if type == "King"
    king = @board.pieces.find { |p| p.type == "King" && p.color == color }
    if king 
      @board.pieces.delete(self)
      if king.is_checked?()
        @attacking_pieces = king.attacking_pieces
        @is_pinned = true
      else
        @is_pinned = false
      end
    end
    @board.pieces.to_set.add(self)
    return @is_pinned
  end
  
  private def generate_bot_moves(piece)
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
    add_move_if_legal(rank, file + direction) if empty_square?(rank, file + direction)

    # Double step from starting rank
    if (color == "White" && file == 6) || (color == "Black" && file == 1)
      add_move_if_legal(rank, file + 2 * direction) if empty_square?(rank, file + direction) && empty_square?(rank, file + 2 * direction)
    end

    # Capture moves
    capture_pawn(rank - 1, file + direction)
    capture_pawn(rank + 1, file + direction)

    # En passant
    add_en_passant_moves(rank, file, direction)
  end

  private def empty_square?(rank, file)
    return !@board.pieces.any? { |p| p.rank == rank && p.file == file }
  end

  private def capture_pawn(target_rank, target_file)
    target_piece = @board.pieces.find { |p| p.x == target_rank * 80 && p.y == target_file * 80 }
    if (target_piece && target_piece.color != color) || @bot
      add_move_if_legal(target_rank, target_file) 
    end
  end

  private def add_en_passant_moves(rank, file, direction)
    last_move = @board.player_move_history.last
    if last_move&.type == "Pawn" && last_move&.can_en_passant
      en_passant_positions = [[rank - 1, file], [rank + 1, file]]
      en_passant_positions.each do |target_rank, _|
        add_move_if_legal(target_rank, file + direction) if last_move.x == target_rank * 80 && last_move.y == @y
      end
    end
  end

  def promotion(choice)
    piece_map = { "Queen" => PieceEval::QUEEN, "Rook" => PieceEval::ROOK, "Bishop" => PieceEval::BISHOP, "Night" => PieceEval::KNIGHT, "Pawn" => PieceEval::PAWN }
    new_piece_type = piece_map[choice] || PieceEval::QUEEN
    promote(new_piece_type | (color == "White" ? PieceEval::WHITE : PieceEval::BLACK), choice)
  end

  private def promote(new_piece_type, choice)
    @piece = new_piece_type
    @piece_image = piece_image(choice[0])
    @promoted = [@board.player_move_history.size, true]
    render_piece
    puts "#{color} promoted to #{type}!"
  end

  private def add_move_if_legal(new_x, new_y)
    return false unless new_x.between?(0, 7) && new_y.between?(0, 7)
    
    target_piece = @board.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80}
    # Empty square or perform a xray attack  
    if target_piece.nil? || (target_piece.type == "King" && target_piece.color != color && @bot)
      @moves.push([new_x, new_y])
      true
    # Capture a piece
    elsif target_piece.color != color
      @moves.push([new_x, new_y])
      false
    # Protect a friendly piece
    elsif target_piece.color == color && @bot
      @moves.push([new_x, new_y])
      false
    end
    
  end
end

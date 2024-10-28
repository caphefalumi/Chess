require 'rubygems'
require 'ruby2d'
require 'set'
class Piece
  attr_accessor :x, :y, :piece, :bot, :position, :moves, :render, :king_color, :is_board, :can_castle, :can_en_passant, :is_moved, :is_checked

  def initialize(x, y, piece, piece_image, game)
    @x, @y, @piece, @piece_image, @game = x, y, piece, piece_image, game
    @moves = []
    @cached_moves = Set.new()
    @bot = false
    @king_color = "White"
    @is_moved = false
    @is_board = false
    @is_checked = true
    @can_en_passant = false
  end

  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y, z: ZOrder::PIECE, width: 80, height: 80)
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

  def generate_moves
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
  def is_checked?(dx = @x / 80, dy = @y / 80, p_color = color)
    king_position = [dx, dy]
    @cached_moves.clear # Clear the cache each time `is_checked?` is called
    @game.pieces.each do |piece|
      next if piece.color == p_color # Only consider opponent pieces
      generate_bot_moves(piece)
      piece.moves.each { |move| @cached_moves.add(move) } # Cache each move of the opponent
      return true if piece.moves.include?(king_position)
    end
    false
  end

  def handle_check
    @game.pieces.each do |piece|
      next if piece.color == "Black" # Only consider white pieces for blocking the check
  
      original_position = piece.position # Save the piece's original position
  
      piece.generate_moves # Generate all potential moves for the piece
      piece.moves.each do |move|
        # Temporarily move the piece to the potential move position
        piece.position = move
        
        # Recheck if the king is still in check after this move
        if !is_checked?(color="Black")
          add_move_if_legal(original_position[0], original_position[1]) # Return this move as it stops the check
          #con la sun ne ba oiii, sun u nuuu If king is not in check, this move can block the check
          piece.position = original_position # Restore the piece's original position
          
        end
      end
  
      piece.position = original_position # Restore the original position if no valid move found
    end
  
    nil # Return nil if no move can stop the check
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
    
    target_piece = @game.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80 }
    if target_piece.nil?
      @moves << [new_x, new_y]
      true
    elsif target_piece.color != color
      @moves << [new_x, new_y]
      false
    elsif target_piece.color == color && color == "Black" && @bot
      @moves << [new_x, new_y]
      false
    end
  end
end

require 'rubygems'
require 'ruby2d'

class Piece
  attr_accessor :x, :y, :piece, :moves, :render, :is_board, :can_castle, :can_en_passant, :is_moved, :is_checked

  def initialize(x, y, piece, piece_image, game)
    @x = x
    @y = y
    @piece = piece
    @piece_image = piece_image
    @moves = Array.new()
    @is_moved = false
    @is_board = false
    @is_checked = true
    @can_en_passant = false
    @game = game
  end

  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y, z: ZOrder::PIECE, width: 80, height: 80)
  end

  def position
    return [@x,@y]
  end

  def name
    color + type if type != "No Piece"
  end

  def color
    @piece & (0b01000 | 0b10000) == 8 ? "White" : "Black"
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

  def generate_moves(bot = false)
    @moves.clear
    case type
    when "King"
      king_moves
    when "Queen", "Rook", "Bishop"
      sliding_moves(type)
    when "Knight"
      knight_moves
    when "Pawn"
      pawn_moves(bot)
    end
  end
  
  # Castling conditions
  def king_moves
    king = @game.pieces.find_all { |p| p.type == "King" }
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    directions.each do |dx, dy|
      new_x = @x / 80 + dx
      new_y = @y / 80 + dy

      if !is_checked?(king, new_x, new_y)
        add_move_if_legal(new_x, new_y)
      end
    end
  
    # Castling conditions
    if !is_moved 
      # King-side castling
      king_side_rook = @game.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == 7 * 80 }
      if king_side_rook && no_pieces_between(king_side_rook)

        add_move_if_legal(6, @y / 80)  # Target position for king-side castling
      end
  
      # Queen-side castling
      queen_side_rook = @game.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == 0 }
      if queen_side_rook && no_pieces_between(queen_side_rook)
        
        add_move_if_legal(2, @y / 80)  # Target position for queen-side castling
      end
    end
  end
  
  def is_checked?(king, x, y)
    # Locate both kings' current positions
    return false unless king

    idx =  @current_turn == :white ? 1 : 0
    king_position = [x, y]
    @game.pieces.each do |piece|
      next unless piece.type != "King" && piece.color == king[idx].color  # Skip captured pieces
      
      if piece.type == "Pawn"
        piece.generate_moves(bot = true)
      else 
        piece.generate_moves # Generate legal moves for the piece
      end
      if piece.moves.include?(king_position)
        return true
      end
    end
    return false
  end
  def no_pieces_between(rook)
    king_file = @x / 80
    rook_file = rook.x / 80
  
    if rook_file < king_file  # Rook is on the left (queen-side)
      (rook_file + 1...king_file).none? do |file| 
        @game.pieces.find { |p| p.x == file * 80 && p.y == @y }
      end
    else  # Rook is on the right (king-side)
      (king_file + 1...rook_file).none? do |file|
        @game.pieces.find { |p| p.x == file * 80 && p.y == @y }
      end
    end
  end
  
  
  def sliding_moves(piece)
    directions = {
      "Rook"   => [[1, 0], [-1, 0], [0, 1], [0, -1]], # Horizontal/Vertical
      "Bishop" => [[1, 1], [-1, -1], [1, -1], [-1, 1]], # Diagonal
      "Queen"  => [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]] # All directions
    }
  
    directions[piece].each do |dx, dy|  # Unpack direction array into dx and dy
      x, y = @x / 80, @y / 80
      loop do
        x += dx   # Add dx for horizontal/vertical change
        y += dy   # Add dy for diagonal or vertical change
        break unless add_move_if_legal(x, y)
      end
    end
  end
  
  def knight_moves
    knight_offsets = [[2, 1], [2, -1], [-2, 1], [-2, -1], [1, 2], [1, -2], [-1, 2], [-1, -2]]
    knight_offsets.each do |dx, dy|
      new_x = @x/80 + dx
      new_y = @y/80 + dy
      add_move_if_legal(new_x, new_y)
    end
  end
  
  def pawn_moves(bot)
    direction = color == "White" ? -1 : 1 # White moves up (-1), Black moves down (1)
    rank = @x / 80
    file = @y / 80
    
    # Forward move (only if the square in front is empty)
    front_square = @game.pieces.find { |p| p.x == rank * 80 && p.y == (file + direction) * 80 }
    add_move_if_legal(rank, file + direction) if front_square.nil?
    
    # Double forward move (if the pawn is on its starting rank and both squares are empty)
    if (color == "White" && file == 6) || (color == "Black" && file == 1)  # White pawn on the 6th rank
      two_squares_ahead = @game.pieces.find { |p| p.x == rank * 80 && p.y == (file + 2 * direction) * 80 }
      add_move_if_legal(rank, file + 2 * direction) if front_square.nil? && two_squares_ahead.nil?
    end
    
    # Capturing diagonally (normal captures)
    left_target_piece = @game.pieces.find { |p| p.x == (rank - 1) * 80 && p.y == (file + direction) * 80 }
    right_target_piece = @game.pieces.find { |p| p.x == (rank + 1) * 80 && p.y == (file + direction) * 80 }
    add_move_if_legal(rank - 1, file + direction) if (left_target_piece && left_target_piece.color != color) || bot
    add_move_if_legal(rank + 1, file + direction) if (right_target_piece && right_target_piece.color != color) || bot
  
    # En passant capture
    if @game.last_move && @game.last_move.type == "Pawn" && @game.last_move.can_en_passant
      en_passant_left = @game.last_move if @game.last_move.x == (rank - 1) * 80 && @game.last_move.y == @y
      en_passant_right = @game.last_move if @game.last_move.x == (rank + 1) * 80 && @game.last_move.y == @y
      
      if en_passant_left
        add_move_if_legal(rank - 1, file + direction) # Add en passant move to the left
      elsif en_passant_right
        add_move_if_legal(rank + 1, file + direction) # Add en passant move to the right
      end
    end
  end

  
  def promotion(choice)
    puts "Pawn promotion! Choose a piece to promote to:"
    puts "1. Queen"
    puts "2. Rook"
    puts "3. Bishop"
    puts "4. Knight"


    new_piece_type = case choice
    when "Queen"
      PieceEval::QUEEN
    when "Rook"
      PieceEval::ROOK
    when "Bishop"
      PieceEval::BISHOP
    when "Night"
      PieceEval::KNIGHT
    else
      PieceEval::QUEEN  # Default to queen if invalid input
    end
    promote(new_piece_type | (color == "White" ? PieceEval::WHITE : PieceEval::BLACK))

  end

  def promote(new_piece_type)
    @piece = new_piece_type
    @piece_image = piece_image(@piece)
    render_piece
    puts "#{color} pawn promoted to #{type}!"
  end
  
  def add_move_if_legal(new_x, new_y)
    if new_x.between?(0, 7) && new_y.between?(0, 7) # Check within bounds
      target_piece = @game.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80 }
      if target_piece.nil? # Legal if empty
        moves << [new_x, new_y] # Store legal move
        return true
      elsif target_piece.color != color # Legal if capturing an opponent
        moves << [new_x, new_y] # Store capturing move
        return false # Stop further moves in this direction
      end
    end 
  end
end

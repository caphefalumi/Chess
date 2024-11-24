require 'set'





class Piece
  attr_reader :piece, :render, :promoted, :blocking_squares
  attr_accessor :x, :y, :pre_x, :pre_y, :bot, :moves, :can_en_passant, :moved_at, :captured_pieces, :promoted, :attacking_pieces, :is_pinned, :is_moved, :is_checked

  def initialize(x, y, piece, board)
    @x, @y, @piece, @board = x, y, piece, board
    @attacking_pieces = Set.new()
    @moves = Set.new()
    @pre_x = Array.new()
    @pre_y = Array.new()
    @captured_pieces = Array.new()
    @promoted = [0, false]
    @bot = false
    @is_moved = false
    @is_pinned = false
    @moved_at = -1
    @can_en_passant = false
    @generating_moves = false
  end

  # Returns the rank of piece on board
  def rank
    @x / 80
  end

  # Returns the file of piece on board
  def file
    @y / 80
  end
  # Return an array of rank and file
  def position
    [@x, @y]
  end

  # Returns a string of the piece's color and type, e.g. "WhiteQueen"
  def name
    color + type
  end

# Determines the color of the piece.
  def color
    (@piece & (0b01000 | 0b10000)) == 8 ? "White" : "Black"
  end

  # Returns a string of the piece's type, e.g. "King", "Queen", "Rook", "Bishop", "Night", "Pawn"
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
  

  # Returns the path to the image for the given piece type. The image filename is of the form
  # "color[0]piece_type[0].png". The path is relative to the current working directory.
  def piece_image(piece_type)
    return "pieces/#{color[0]}#{piece_type[0]}.png"
  end

  # Renders the piece on the board as an image. The image is determined by the piece's
  # type and color. The image is placed at the piece's current position, with a z-order
  # of ZOrder::PIECE. The size of the image is 80x80.
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

  # Returns the value of the chess piece based on its type.
  #
  # Each piece type is assigned a specific value:
  # - King: 20000
  # - Queen: 900
  # - Rook: 500
  # - Bishop: 350
  # - Night: 320
  # - Pawn: 100
  #
  # @return [Integer] the value of the piece
  def get_value
    case type
    when "King" then 20000
    when "Queen" then 900
    when "Rook" then 500
    when "Bishop" then 350
    when "Night" then 320
    when "Pawn" then 100
    end
  end

  
  
  # Generates all the possible moves for a given piece.
  #
  # This method is used in the Board#get_moves method to generate all the possible moves
  # for all the pieces on the board. The moves are generated based on the type of piece
  # and are stored in the @moves instance variable. This method is overridden in the
  # subclasses to provide specific move generation logic for each type of piece. The
  # generated moves are used to determine the best move in the minimax algorithm.
  #
  # @return [void]
  def generate_moves()
    @moves.clear
    case type
    when "King"    then king_moves
    when "Queen", "Rook", "Bishop" then sliding_moves(type)
    when "Night"  then knight_moves
    when "Pawn"    then pawn_moves
    end
  end

  # Generates all the possible moves for a given piece when it is attacking the king.
  #
  # This method is used in the get_attack_moves method to generate all the possible
  # moves for all the pieces on the board that are attacking the king. The moves are generated
  # based on the type of piece and are stored in the @moves instance variable. This method is
  # overridden in the subclasses to provide specific move generation logic for each type of
  # piece. The generated moves are used to determine the best move in the minimax algorithm when
  # the king is in check.
  def generate_attack_moves 
    king_color = @board.pieces.find { |p| p.type == "King" && p.color == @current_turn }
    if king_color != color
      generate_moves
    end
  end

  # Generates all the possible moves for the king piece.
  #
  # This method overrides the `generate_moves` method to generate the
  # moves for the king piece. The moves are generated based on the type
  # of piece and are stored in the `@moves` instance variable. This method
  # generates all the possible moves for the king piece, including
  # castling moves.
  private def king_moves
    @generating_moves = true
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    directions.each do |dx,dy|
      add_move_if_legal(rank + dx, file + dy) if @board.player_playing && !is_checked?(rank + dx, file + dy)
    end
    if !is_moved && !@board.checked
      king_side_rook = find_castling_rook(7 * 80)
      queen_side_rook = find_castling_rook(0)
      add_move_if_legal(6, file) if king_side_rook && no_pieces_between(king_side_rook) && @board.player_playing && !is_checked?(6, file)
      add_move_if_legal(2, file) if queen_side_rook && no_pieces_between(queen_side_rook) && @board.player_playing && !is_checked?(2, file)
    end
    @generating_moves = false
  end


  # Finds the rook that can be used for castling at a given file position.
  private def find_castling_rook(file_position)
    @board.pieces.find { |p| p.type == "Rook" && !p.is_moved && p.color == color && p.x == file_position }
  end

  # Checks if there are any pieces between the current piece (King) and the specified
  # rook piece, on the same rank (@y). If there are any pieces, returns false. If not,
  # returns true.
  private def no_pieces_between(rook)
    king_file = @x / 80
    rook_file = rook.x / 80
  
    # Determine the range of files to check between King and Rook
    files_between = (king_file < rook_file) ? (king_file + 1...rook_file) : (rook_file + 1...king_file)
  
    # Check if any pieces exist in the specified range on the same rank (@y)
    files_between.each do |file|
      return false if @board.pieces.any? { |piece| piece.x == file * 80 && piece.y == @y }
    end
  
    return true
  end
  

  # Checks if the King is in check at the given rank and file.
  #
  # @param rank [Integer] the rank of the King to check
  # @param file [Integer] the file of the King to check
  # @return [Boolean] whether the King is in check at the given position
  def is_checked?(rank = @x / 80, file = @y / 80)
    king_position = [rank, file]
    is_checked = false
  
    @board.pieces.each do |piece|
      next if piece.color == color # Only consider opponent pieces
  
      # Special case for opponent King: check adjacent squares
      if piece.type == "King"
        if (piece.rank - rank).abs <= 1 && (piece.file - file).abs <= 1
          is_checked = true
          break
        end
        next
      end
  
      generate_bot_moves(piece)
      if piece.moves.include?(king_position)
        if piece.type == "Pawn" && piece.rank == king_position[0]
          is_checked = false
        else
          @attacking_pieces.add(piece) if !@generating_moves
          is_checked = true
          break if @attacking_pieces.size == 2 # Optimization: Stop if two attackers are found
        end
      end
    end
    return is_checked
  end
  

  # Checks if the piece is pinned against the King. This is done by temporarily
  # removing the piece from the board and checking if the King is in check.
  # If the King is in check, the piece is pinned and the attacking piece(s) are
  # stored in the @attacking_pieces set. If not, the piece is not pinned.
  #
  # @return [Boolean] whether the piece is pinned against the King
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
  
  # Makes the piece generate moves as if it were a bot, then returns the piece to
  # its original state. This is used to check if a piece is pinned against the
  # King.
  private def generate_bot_moves(piece)
    piece.bot = true
    piece.generate_attack_moves
    piece.bot = false
  end


  # Generates moves for sliding pieces, such as Rooks, Bishops, and Queens.
  # The moves are generated in all eight directions, and the loop breaks
  # when the piece is blocked by another piece or the move is illegal.
  # The generated moves are added to the piece's moves Set.
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

  # Generates all potential knight moves from the piece's current position.
  private def knight_moves
    knight_offsets = [[2, 1], [2, -1], [-2, 1], [-2, -1], [1, 2], [1, -2], [-1, 2], [-1, -2]]
    knight_offsets.each do |dx, dy| 
      add_move_if_legal(@x / 80 + dx, @y / 80 + dy)
    end
  end

  # Generates moves for pawns, including single and double steps from the starting
  # rank, capture moves, and en passant moves. The moves are added to the piece's
  # moves Set.
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

  # Checks if the square at the given rank and file is empty
  private def empty_square?(rank, file)
    return !@board.pieces.any? { |p| p.rank == rank && p.file == file }
  end

  # Checks if the square at the given rank and file contains an opponent's pawn
  # that can be captured. If so, adds the move to the piece's moves Set.
  private def capture_pawn(target_rank, target_file)
    target_piece = @board.pieces.find { |p| p.x == target_rank * 80 && p.y == target_file * 80 }
    if (target_piece && target_piece.color != color) || @bot
      add_move_if_legal(target_rank, target_file) 
    end
  end

  # This method checks if the last move made was a pawn move that allowed for an
  # en passant capture. If so, it calculates the potential en passant capture positions
  # and adds them to the piece's legal moves if they are valid.
  private def add_en_passant_moves(rank, file, direction)
    last_move = @board.player_move_history.last
    if last_move&.type == "Pawn" && last_move&.can_en_passant
      en_passant_positions = [[rank - 1, file], [rank + 1, file]]
      en_passant_positions.each do |target_rank, _|
        add_move_if_legal(target_rank, file + direction) if last_move.x == target_rank * 80 && last_move.y == @y
      end
    end
  end

  # Promotes a pawn to the specified choice of piece type (Queen, Rook, Bishop, Knight, Pawn).
  # Uses a hash to map the choice to the corresponding PieceEval constant.
  # If the choice is not found in the hash, defaults to a Queen.
  # Calls the private method #promote to replace the pawn with the chosen piece type.
  def promotion(choice)
    piece_map = { "Queen" => PieceEval::QUEEN, "Rook" => PieceEval::ROOK, "Bishop" => PieceEval::BISHOP, "Night" => PieceEval::KNIGHT, "Pawn" => PieceEval::PAWN }
    new_piece_type = piece_map[choice] || PieceEval::QUEEN
    promote(new_piece_type | (color == "White" ? PieceEval::WHITE : PieceEval::BLACK), choice)
  end

# Replaces the current pawn with a new piece of the specified type.
# Updates the internal piece representation and image to reflect the promotion.
# Sets the promoted flag to true and records the move history size at the time of promotion.
# Finally, renders the promoted piece on the board.
#
# @param new_piece_type [Integer] the new type of the piece, combined with color, using PieceEval constants
# @param choice [String] the chosen piece type as a string, used to determine the piece image
  private def promote(new_piece_type, choice)
    @piece = new_piece_type
    @piece_image = piece_image(choice[0])
    @promoted = [@board.player_move_history.size, true]
    render_piece
  end

  # Adds a new move to the list of legal moves if the move is legal
  # and returns true if the move is a capture, false if it is a non-capture move.
  # If the move is illegal, it returns false.
  #
  # @param new_x [Integer] the x-coordinate of the target move
  # @param new_y [Integer] the y-coordinate of the target move
  # @return [Boolean] whether the move is a capture or not
  private def add_move_if_legal(new_x, new_y)
    return false unless new_x.between?(0, 7) && new_y.between?(0, 7)
    
    target_piece = @board.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80}
    # Empty square or perform a xray attack  
    if target_piece.nil? || (target_piece.type == "King" && target_piece.color != color && @bot)
      @moves.add([new_x, new_y])
      true
    # Capture a piece
    elsif target_piece.color != color
      @moves.add([new_x, new_y])
      false
    # Protect a friendly piece
    elsif target_piece.color == color && @bot
      @moves.add([new_x, new_y])
      false
    end
    
  end
end

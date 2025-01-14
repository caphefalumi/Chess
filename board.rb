require 'ruby2d'
require 'set'
require_relative 'piece'
require_relative 'chess_engine'





module ZOrder
  BOARD, OVERLAP, PIECE, PROMOTION = *0..3
end

class Sounds
  attr_reader :capture, :castle, :illegal, :move_check, :move_self, :promote, :game_start, :game_end

  def initialize
    @capture = Music.new("sounds/capture.mp3")
    @castle = Music.new("sounds/castle.mp3")
    @illegal = Music.new("sounds/illegal.mp3")
    @move_check = Music.new("sounds/move_check.mp3")
    @move_self = Music.new("sounds/move_self.mp3")
    @game_start = Music.new("sounds/game_start.mp3")
    @game_end = Music.new("sounds/game_end.mp3")
    @promote = Music.new("sounds/promote.mp3")
  end
end

class PieceEval
  NONE   = nil
  KING   = 1
  PAWN   = 2
  BISHOP = 3
  KNIGHT = 4
  ROOK   = 5
  QUEEN  = 6
  WHITE  = 8
  BLACK  = 16
end


class Board
  attr_reader :game_over
  attr_accessor :clicked_piece, :time, :checked, :pieces, :current_turn, :render, :player_playing, :player_move_history
  def initialize
    @sounds = Sounds.new()
    @pieces = Set.new()
    @moves = Set.new()
    @player_move_history = Array.new()
    @clicked_piece = nil
    @checked = false
    @promotion = false
    @is_piece_clicked = false
    @player_playing = true
    @time = 0
    @render = true
    @current_turn = "White"
    @board = initialize_board
    @engine = Engine.new(self)
    draw_board
  end

  # Initializes a new chess board.
  # This method returns a 2D array representing a chess board. The
  # array is 8x8 and each element of the array is a Piece object.
  # The board is initialized with the standard starting pieces.
  def initialize_board
    [
      [PieceEval::ROOK | PieceEval::BLACK, PieceEval::KNIGHT | PieceEval::BLACK, PieceEval::BISHOP | PieceEval::BLACK, PieceEval::QUEEN | PieceEval::BLACK, PieceEval::KING | PieceEval::BLACK, PieceEval::BISHOP | PieceEval::BLACK, PieceEval::KNIGHT | PieceEval::BLACK, PieceEval::ROOK | PieceEval::BLACK],
      [PieceEval::PAWN | PieceEval::BLACK] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::PAWN | PieceEval::WHITE] * 8,
      [PieceEval::ROOK | PieceEval::WHITE, PieceEval::KNIGHT | PieceEval::WHITE, PieceEval::BISHOP | PieceEval::WHITE, PieceEval::QUEEN | PieceEval::WHITE, PieceEval::KING | PieceEval::WHITE, PieceEval::BISHOP | PieceEval::WHITE, PieceEval::KNIGHT | PieceEval::WHITE, PieceEval::ROOK | PieceEval::WHITE]
    ]
  end

  # Draws the board and pieces.
  #
  # This method is used to draw the board as well as all the pieces
  # on the board. It iterates over the @board array and draws a
  # square at each position. If the square contains a piece, it
  # creates a new Piece object, renders it, and adds it to the
  # @pieces set.
  def draw_board
    (0..8).each do |rank|
      (0...8).each do |file|
        is_light_square = (rank + file) & 1 != 0
        square_color = is_light_square ? "#6e4e36" : "#b99b75"
  
        # Draw square
        Square.new(
          x: rank * 80,
          y: file * 80,
          size: 80,
          z: ZOrder::BOARD,
          color: square_color
        )
  
        # Get the piece at the current position
        piece_pos = @board[file][rank]
        # Create and store the piece object
        if piece_pos
          piece = Piece.new(rank * 80, file * 80, piece_pos, self)
          piece.render_piece
          @pieces.add(piece)
        end
      end
    end
    @sounds.game_start.play
  end
  
# Handles mouse click events on the board.
#
# This method determines the rank and file of the clicked position based on the
# mouse coordinates and processes the click based on the current game state.
# If the left mouse button is clicked, it clears any previous selection and
# handles specific game states, including checkmate, promotion, and normal piece
# selection and movement. It resets the illegal move state if a piece is clicked
# during an illegal state.
  def handle_mouse_click(mouse)
    rank, file = (mouse.x / 80).to_i, (mouse.y / 80).to_i
    @mouse_x, @mouse_y = mouse.x, mouse.y
    case mouse.button
    when :left
      clear_previous_selection if @clicked_square && (@target_square || @illegal_state)
      
      # Reset the illegal state if a piece is clicked, and allow new selection
      @illegal_state = false if @clicked_piece && @illegal_state
  
      if @game_over
        handle_checkmate()
      elsif @promotion
        handle_promotion()
      elsif @current_turn
        if !@is_piece_clicked
          select_piece(rank, file)
        else
          make_move(@clicked_piece, rank, file)
        end
      end
    end
  end
  
  # Switches the current turn to the other player.
  # If the game is in player vs AI mode and the current turn is black, the AI makes a move.
  def turn
    @current_turn = @current_turn == "White" ? "Black" : "White"
    if @player_playing && @current_turn == "Black" && !@game_over
      @engine.minimax
    end
  end

  # Returns true if the mouse click is within the given area
  def area_clicked(leftX, topY, rightX, bottomY)
		return @mouse_x >= leftX && @mouse_x <= rightX && @mouse_y >= topY && @mouse_y <= bottomY
  end

  # Selects a piece at the given rank and file, and handles the case if it is in check or pinned
  def select_piece(rank, file)
    @clicked_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 }
    if @clicked_piece
      king = @pieces.find { |p| p.type == "King" && p.color == @current_turn }
      @clicked_piece.generate_moves
      if @checked
        handle_check(@clicked_piece, king)
      else
        handle_pin(@clicked_piece, king)
      end

      highlight_selected_piece(rank, file)
      draw_possible_moves(@clicked_piece.moves)
      @is_piece_clicked = true
    end
  end
  
  # Highlights all possible moves for the selected piece
  def draw_possible_moves(moves)
    moves.each do |move|
      move_circle = Circle.new(
        x: move[0] * 80 + 40,
        y: move[1] * 80 + 40,
        z: ZOrder::OVERLAP,
        radius: 10,
        color: 'black'
      )
      target_piece_square = @pieces.find { |p| p.x == move[0] * 80 && p.y == move[1] * 80 }
  
      if target_piece_square
        move_circle.radius = 15
        move_circle.color.opacity = 0.5
        move_circle.z = ZOrder::PIECE + 1
      else
        move_circle.color.opacity = 0.4
      end
  
      @moves.add(move_circle)
    end
  end  

  # Finds all possible moves for the current turn.
  #
  # @return [Set] a set of hashes containing the piece and its target move
  #   Each hash has the keys :piece and :to
  #   :piece is the Piece object
  #   :to is an array [rank, file] of the target move
  # @example
  #   get_moves
  #   # => [{ piece: Piece, to: [rank, file] }, { ... }]
  def get_moves()
    time1 = Time.new
    available_moves = Set.new
    # Find all pieces for the current turn and calculate their moves
    @pieces.each do |piece|
      next if piece.color != @current_turn # Skip pieces of the other color
      # Generate legal moves for this piece
      piece.generate_moves
      piece.moves.each do |move|
        available_moves.add ({ piece: piece, to: move })
      end
    end
    time2 = Time.new
    time = time2 - time1
    @time += time
    return available_moves
  end

  # Move the piece or capture an opponent piece
  def make_move(piece, rank, file, bot_move=false)
    # return if not piece  
    target_move = [rank, file]
    # # Check if the target move is in the list of legal moves
    if !piece.moves.include?(target_move) && @player_playing && !bot_move
      handle_illegal_move
      reset_state_after_move
      return
    end
  
    target_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 }
    move_piece(piece, rank, file)

    piece.captured_pieces << target_piece

    if target_piece
      capture_piece(target_piece)
    end
    
    @player_move_history << piece 
    
    is_check
    reset_state_after_move
    turn if !@promotion

  end
  
  # Checks if the current turn's king is under attack.
  #
  # @return [Boolean] whether the king is under attack
  def is_check
    king = @pieces.find { |p| p.type == "King" && p.color != @clicked_piece.color }
    if king&.is_checked?()
      @sounds.move_self.pause
      @sounds.move_check.play if @player_playing
      @checked = true
      @no_legal_moves = true
      blocking_squares = calculate_blocking_squares(king.position, king.attacking_pieces.first)
      @pieces.each do |loop_piece|
        next if loop_piece.color != king.color || loop_piece.type == "King"
        loop_piece.generate_moves
        loop_piece.moves.each do |move|
          if blocking_squares.include?(move)
            @no_legal_moves = false
          end
        end
      end

      king.generate_moves
      if @no_legal_moves && king.moves.empty?
        @game_over = true
        checkmate_ui
      end
    else
      king&.attacking_pieces&.clear
      @checked_king = nil
      @checked = false
      @white_check = false
      @black_check = false
    end
  end

# Moves the specified piece to the target rank and file. Updates the piece's
# position history and handles special move types such as castling,
# promotion, and en passant. If rendering is enabled, the move is visually
# represented on the board. Plays appropriate sounds based on the move type.
#
# @param piece [Piece] the piece to be moved
# @param rank [Integer] the target rank position on the board
# @param file [Integer] the target file position on the board
  def move_piece(piece, rank, file)
    piece.pre_x << piece.x
    piece.pre_y << piece.y
    piece.moved_at = @player_move_history.size if piece.moved_at == -1
    promotion_flag = false
    castle_flag = false
    en_passant_flag = false
    start_x = piece.x
    start_y = piece.y

    if @render 
      # @target_square.remove if @target_square
      @target_square = Square.new(
        x: rank * 80,
        y: file * 80,
        z: ZOrder::OVERLAP,
        size: 80,
        color: "#B58B37"
      )
      @target_square.color.opacity = 0.8

    end
    render_at_new_pos(piece, rank, file)

    if piece.type == "Pawn" && ((start_y + 160 == piece.y && piece.color == "Black") || 
      (start_y - 160 == piece.y && piece.color == "White"))
      piece.can_en_passant = true
    end

    # Castle
    if piece.type == "King" && start_x == 4 * 80 && (rank == 6 || rank == 2)
      castle(rank, file)
      castle_flag = true
    # Promotion
    elsif piece.type == "Pawn" && (file == 7 || file == 0)
      promotion_ui
      promotion_flag = true
    # En passant
    elsif @player_move_history.last && @player_move_history.last.color != piece.color && piece.type == "Pawn" && @player_move_history.last.type == "Pawn"
      if (start_x + 80 == piece.x || start_x - 80 == piece.x) && 
        ((start_y + 80 == piece.y && piece.color == "Black") || 
        (start_y - 80 == piece.y && piece.color == "White"))
        
        capture_piece(@player_move_history.last)
        en_passant_flag = true
      end
    end

    if !promotion_flag && !castle_flag && !en_passant_flag && @render
      @sounds.move_self.play 
    end
  end
  
  # Reverts the last move made by a player. Handles castling, promotion and regular captures.
  # Restores the piece's previous position, removes any rendered moves, and resets the state
  # of the game. Switches the turn back to the previous player.
  def unmake_move
    # Return if there are no past moves
    return if @player_move_history.empty?
  
    # Get the last moved piece from the history
    piece_to_undo = @player_move_history.pop
    # If there's no piece to undo, return early
    return if piece_to_undo.nil?

    current_x = piece_to_undo.x
    
    # Restore the piece's previous position
    piece_to_undo.render.remove if @render
    piece_to_undo.x = piece_to_undo.pre_x.pop
    piece_to_undo.y = piece_to_undo.pre_y.pop
    piece_to_undo.render_piece if @render
  
    if piece_to_undo.moved_at == @player_move_history.size
      piece_to_undo.is_moved = false
    end
    # Handle castling
    if piece_to_undo.type == "King" && (current_x - piece_to_undo.x).abs == 160
      # Determine which rook to move back
      rook_old_x = current_x > piece_to_undo.x ? 5 * 80 : 3 * 80
      rook_new_x = current_x > piece_to_undo.x ? 7 * 80 : 0
      rook = @pieces.find { |p| 
        p.type == "Rook" && 
        p.color == piece_to_undo.color && 
        p.x == rook_old_x && 
        p.y == piece_to_undo.y
      }
      
      if rook
        rook.render.remove if @render
        rook.x = rook_new_x
        rook.render_piece if @render
        rook.is_moved = false
      end
      piece_to_undo.is_moved = false
    end

    # Handle promotion
    if piece_to_undo.promoted[0] - 1 == @player_move_history.size && piece_to_undo.promoted[1] == true
      piece_to_undo.render.remove if @render
      piece_to_undo.promotion("Pawn")
      piece_to_undo.promoted = [@player_move_history.size, false]
    end
    
    # Restore captured piece if any (regular capture)
    captured_piece = piece_to_undo.captured_pieces.pop
    if captured_piece
      captured_piece.render_piece if @render
      @pieces.add(captured_piece)
    end

    @checked = false
    @game_over = false
    # Clear highlights and reset state
    clear_previous_selection(only_moves: false)
    reset_state_after_move
  
    # Switch turn back to the previous player
    @current_turn = @current_turn == "White" ? "Black" : "White"
  

  end

  # Captures the opponent's piece
  def capture_piece(target_piece)
    target_piece.render.remove if @render
    puts " #{target_piece.name}"
    @pieces.delete(target_piece)
    @sounds.capture.play if @render
  end

  # Called when a player makes a promotion move. Automatically promotes black pawns to
  # Queens, and displays a promotion menu for white pawns. The promotion menu consists of
  # a gray rectangle with four options: Queen, Rook, Bishop, and Knight. The user can click
  # on one of the options to select the promotion piece. If the user is playing as black,
  # the promotion is automatically done.
  def promotion_ui()
    if !@player_playing
      # Automatically promote black pawn to Queen
      @clicked_piece.promotion("Queen")
      @promotion = false
      turn
    else
      # Display promotion UI for white pieces
      @promotion_options = Array.new()
      @promotion_menu_rect = Rectangle.new(
        x: @clicked_piece.x,
        y: @clicked_piece.y,
        z: ZOrder::PROMOTION,
        width: 80,
        height: 320,
        color: 'gray'
      )
      %w[Queen Rook Bishop Night].each_with_index do |piece_type, i|
        piece_image = Image.new("pieces/#{@clicked_piece.color[0]}#{piece_type[0]}.png", x: @clicked_piece.x, y: @clicked_piece.y + i * 80, width: 80, height: 80, z: 5)
        @promotion_options << [piece_image, piece_type]
      end
      @promotion = true
    end
  end
  
  # Called when a player makes a promotion move. Checks if the mouse is
  # within the bounds of one of the promotion pieces, and if so, removes the
  # old piece, promotes the piece to the selected type, removes the promotion
  # menu, and ends the promotion mode.
  def handle_promotion()
    (0..3).each do |i|
      image = @promotion_options[i][0]
      if area_clicked(image.x, image.y, image.x + image.width, image.y + image.height)
        selected_type = @promotion_options[i][1]
        @clicked_piece.render.remove
        @clicked_piece.promotion(selected_type)
        @promotion_options.each { |opt| opt[0].remove }
        @promotion_options.clear
        @promotion_menu_rect.remove
        @promotion = false
        @sounds.promote.play
        turn
        break
      end
    end
  end

  # Castles the king with the rook at the specified rank and file, if the rook has not moved before.
  # The rook is moved to its new position, and the castle sound is played if the board is being rendered.
  def castle(rank, file)
    rook_x = rank == 6 ? 7 * 80 : 0
    rook = @pieces.find { |p| p.type == "Rook" && p.color == @clicked_piece.color && p.x == rook_x && p.is_moved == false}
    rook_new_x = rank == 6 ? 5 : 3
    if rook
      # Move rook to its new position
      render_at_new_pos(rook, rook_new_x, rook.file)
      @sounds.castle.play if @render
    end
  end


# Handles the scenario where a piece is selected while the king is in check.
# If the king is being attacked by two pieces, it clears the moves of the selected piece
# unless it is the king itself. Otherwise, it updates the legal moves of the piece
# to ensure the king's safety.
  def handle_check(piece, king)
    if piece.type != "King" && king.attacking_pieces.size == 2
      piece.moves.clear
    else
      update_legal_moves(piece, king)
    end
  end
  
  # Updates the legal moves for the given piece based on whether the piece is pinned.
  # If the piece is pinned, it calculates the blocking squares and removes moves
  # that are not part of those blocking squares from the piece's moves.
  def handle_pin(piece, king)
    if piece.type != "King" && piece.is_pinned?
      update_legal_moves(piece, king)
    end
  end
  

# Updates the legal moves for the given piece based on whether the king is under attack.
# If the king is being attacked, it calculates the blocking squares and removes moves
# that are not part of those blocking squares from the piece's moves.
  def update_legal_moves(piece, king)
    if king.attacking_pieces.any?
      blocking_squares = calculate_blocking_squares(king.position, king.attacking_pieces.first) 
      piece.moves -= illegal_moves(blocking_squares, piece) 
    end
  end

# Filters out moves that do not block a check.
  def illegal_moves(blocking_squares, piece)
    moves_to_delete = []
    if piece.type != "King"
      piece.moves.each do |move|
        if !blocking_squares.include?(move)
          moves_to_delete << move
        end
      end
    end
    return moves_to_delete
  end

  # Given a king position and an attacking piece, calculates the set of squares that
  # would block the check if moved to. For non-knight pieces, this is the set of squares
  # between the king and the attacking piece. For knight pieces, this is just the square
  # the knight is on. Returns a Set of squares as [x, y] coordinates.
  def calculate_blocking_squares(king_pos, attacking_piece)
    blocking_squares = Set.new
    
    # Calculate direction vectors dx and dy

    dx = (attacking_piece.x - king_pos[0]) <=> 0
    dy = (attacking_piece.y - king_pos[1]) <=> 0
    
    # Initialize x and y positions one step away from the king
    x, y = king_pos[0] + dx * 80, king_pos[1] + dy * 80
    count = 0
    
    # Only calculate for non-knight pieces
    if attacking_piece.type == "Night"
      blocking_squares.add([attacking_piece.rank, attacking_piece.file])
    else
      # Iterate to add each blocking square until reaching the attacking piece
      while [x, y] != [attacking_piece.x + dx * 80, attacking_piece.y + dy * 80]
        break if count == 100  # Prevent infinite loop due to unfound move to block the check
        
        # Add square to blocking_squares, converting to board coordinates
        blocking_squares.add([x / 80, y / 80])
        
        # Move to the next square in the direction of the attacker
        x += dx * 80
        y += dy * 80
        count += 1
      end
    end
  
    return blocking_squares.to_a
  end

  # Creates UI elements for displaying the game result (win/lose/draw)
  #
  # Includes an overlay, a dialog box, winner text, and a "Play Again" button
  #
  # The UI elements are added to the `@overlay`, `@dialog`, `@game_result`, 
  # `@play_again_button`, and `@play_again_text` instance variables.
  def game_result_ui()
    @overlay = Rectangle.new(
      x: 0,
      y: 0,
      width: 640,
      height: 640,
      color: 'black',
      z: ZOrder::PROMOTION
    )
    @overlay.color.opacity = 0.7

    # Main dialog box
    @dialog = Rectangle.new(
      x: 120,
      y: 180,
      width: 400,
      height: 280,
      color: 'white',
      z: ZOrder::PROMOTION + 1
    )

    # Winner text
    @game_result = Text.new("",
      x: 180,
      y: 240,
      size: 24,
      color: 'black',
      z: ZOrder::PROMOTION + 1
    )

    # Play Again button
    @play_again_button = Rectangle.new(
      x: 220,
      y: 340,
      width: 200,
      height: 50,
      color: '#2F70FF',
      z: ZOrder::PROMOTION + 1
    )

    @play_again_text = Text.new(
      'Play Again',
      x: 270,
      y: 355,
      size: 20,
      color: 'white',
      z: ZOrder::PROMOTION + 1
    )
  end
  
# Displays the checkmate UI and plays the game end sound if the player is currently playing.
# Updates the game result text to show which player wins by checkmate.
  def checkmate_ui()
    if @player_playing
      @sounds.game_end.play
      game_result_ui
      # Winner text
      @game_result.text = "#{@current_turn == "White" ? 'White' : 'Black'} wins by checkmate!"
    end
  end

  # Handles the play again button click, reseting the board to its initial state
  # and removing the checkmate UI.
  def handle_checkmate()
    if area_clicked(@play_again_button.x, @play_again_button.y, @play_again_button.x + @play_again_button.width, @play_again_button.y + @play_again_button.height)
      reset_board
      @overlay.remove
      @dialog.remove
      @game_result.remove
      @play_again_text.remove
      @play_again_button.remove
    end
  end

  # Move the clicked piece to the new coordinates
  def render_at_new_pos(piece, rank, file)
    piece.is_moved = true
    piece.render.remove if @render
    piece.x = rank * 80 
    piece.y = file * 80
    piece.render_piece if @render
  end

  # Highlight the illegal move visually
  def highlight_illegal_move(piece)
    # Flash the piece briefly in red or create another effect to show the illegal attempt
    flash_square = Square.new(
      x: piece.x,
      y: piece.y,
      z: ZOrder::OVERLAP,
      size: 80,
      color: "red"
    )
    flash_square.color.opacity = 0.8
  
    # After a short delay, remove the red flash (simulating feedback)
    Thread.new do
      sleep(0.2)
      flash_square.remove
    end
  end

  # Highlights the selected piece on the board
  def highlight_selected_piece(rank, file)
    clear_previous_selection(only_moves: false)
    @clicked_square = Square.new(
      x: rank * 80,
      y: file * 80,
      z: ZOrder::OVERLAP,
      size: 80,
      color: "#B58B37"
    )
    @clicked_square.color.opacity = 0.8
  end
  
  # Handles an illegal move by playing a sound, visually highlighting the piece, 
  # and setting the illegal state flag.
  def handle_illegal_move
    @sounds.illegal.play
    highlight_illegal_move(@clicked_piece)
    @illegal_state = true
  end

  # Clears previous selections and moves if necessary
  def clear_previous_selection(only_moves: true)
    # Clear only the possible move circles (not square highlights) if only_moves is true
    if !only_moves
      @target_square&.remove
      @clicked_square&.remove
    end
    @moves.each(&:remove)
    @moves.clear
  end

  # Resets the state after the move is completed
  def reset_state_after_move
    @is_piece_clicked = false
    clear_previous_selection(only_moves: true)
  end 

# Resets the chess board to its initial state.
#
# This method clears all pieces from the board, removes any visual highlights
# or selection indicators, and reinitializes the board to the standard starting
# position for a new game. It also resets game state variables such as the
# current turn, check status, and promotion flags.
  def reset_board
    @pieces.each { |piece| piece.render.remove }
    @pieces.clear
    @clicked_square&.remove
    @target_square&.remove
    @moves.each(&:remove)
    @moves.clear
    @current_turn = "White"
    @checked = false
    @clicked_piece = nil
    @is_piece_clicked = false
    @game_over = false
    @promotion = false
    @board = initialize_board
    draw_board
  end
end
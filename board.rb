require 'ruby2d'
require 'set'
require 'benchmark'
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
  NONE   = 0
  KING   = 1
  PAWN   = 2
  BISHOP = 3
  KNIGHT = 4
  ROOK   = 5
  QUEEN  = 6
  WHITE  = 8
  BLACK  = 16
end

# Helper function to return image file path based on piece
def piece_image(piece)
  color = piece & (0b01000 | 0b10000) == 8 ? "w" : "b"
  type = piece & 0b00111
  case type
  when PieceEval::KING   then "pieces/#{color}k.png"
  when PieceEval::QUEEN  then "pieces/#{color}q.png"
  when PieceEval::ROOK   then "pieces/#{color}r.png"
  when PieceEval::BISHOP then "pieces/#{color}b.png"
  when PieceEval::KNIGHT then "pieces/#{color}n.png"
  when PieceEval::PAWN   then "pieces/#{color}p.png"
  end
end


class Board
  attr_reader :pieces, :last_move, :checked, :game_over
  attr_accessor :clicked_piece, :current_turn
  def initialize
    @sounds = Sounds.new()
    @pieces = Set.new()
    @moves = Set.new()
    @valid_moves = Set.new()
    @move_history_past = Array.new()
    @move_history_future = Array.new()
    @number_of_moves = -1
    @clicked_piece = nil
    @last_move = nil
    @checked = false
    @promotion = false
    @is_piece_clicked = false
    @current_turn = "White"
    @board = initialize_board
    @engine = Engine.new(self)
    draw_board
  end

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

  def draw_board
    (0..8).each do |rank|  # Count down from 7 to 0
      (0...8).each do |file|       # Still count up from 0 to 7 for files
        is_light_square = (rank + file) % 2 != 0
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
        image_file = piece_image(piece_pos)
        # Create and store the piece object
        if image_file
          piece = Piece.new(rank * 80, file * 80, piece_pos, image_file, self)
          piece.render_piece
          @pieces.add(piece)
        end
      end
    end
    @sounds.game_start.play
  end
  
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
          make_move(rank, file)
        end
      end
    end
  end
  
  def turn
    @last_move = @clicked_piece
    # @current_turn = @current_turn == "White" ? "Black" : "White"
    # @engine.random
  end

  def area_clicked(leftX, topY, rightX, bottomY)
		return @mouse_x >= leftX && @mouse_x <= rightX && @mouse_y >= topY && @mouse_y <= bottomY
  end

  def select_piece(rank, file)
    @clicked_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 }

    if @clicked_piece
      king = @pieces.find { |p| p.type == "King" && p.color == @clicked_piece.color }
      @clicked_piece.generate_moves
      if @checked
        handle_check(@clicked_piece, king)
      else
        handle_pin(@clicked_piece, king)
      end

      highlight_selected_piece(@clicked_piece.x, @clicked_piece.y)
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

  def get_moves
    available_moves = []

    # Find all pieces for the current turn and calculate their moves
    @pieces.each do |piece|
      next if piece.color != @current_turn.to_s.capitalize # Skip pieces of the other color

      # Generate legal moves for this piece
      piece.generate_moves

      # For pieces that are pinned, calculate the blocking squares
      if @checked
        handle_pin(piece, king) 
      else
        handle_check(piece, king)
      end

      # Add valid moves for this piece to the list, including its position
      available_moves << { piece: piece, from: [piece.x / 80, piece.y / 80], to: piece.moves }
    end

    return available_moves
  end

  
  # Attempts to move the piece or capture an opponent piece
  def make_move(piece = @clicked_piece, rank, file)
    return if not piece  
  
    target_move = [rank, file]
  
    # Check if the target move is in the list of legal moves
    if not piece.moves.include?(target_move)
      clear_previous_selection(only_moves: false)
      handle_illegal_move
      reset_state_after_move
      return
    end
  
    target_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 }
    move_piece(piece, rank, file)

    if target_piece&.color == piece.color
      handle_illegal_move

    elsif target_piece
      capture_piece(piece, target_piece)
    end
    @move_history_past << piece
    # @number_of_moves += 1
    is_check
    
    turn if !@promotion

    reset_state_after_move
  end
  
  def is_check
    king = @pieces.find { |p| p.type == "King" && p.color != @clicked_piece.color }
    if king&.is_checked?()
      @sounds.move_check.play
      @checked = true
    else
      king&.attacking_pieces.clear
      @checked = false
    end
  end

  def move_piece(piece, rank, file)
    piece.pre_x << piece.x
    piece.pre_y << piece.y
    @target_square = Square.new(
      x: rank * 80,
      y: file * 80,
      z: ZOrder::OVERLAP,
      size: 80,
      color: "#B58B37"
    )
    @target_square.color.opacity = 0.8
    castle_flag = false
    capture_flag = false
    promotion_flag = false
    en_passant_flag = false
    start_x = piece.x
    start_y = piece.y

    render_at_new_pos(rank, file)

    if piece.type == "Pawn" && ((start_y + 160 == piece.y && piece.color == "Black") || 
      (start_y - 160 == piece.y && piece.color == "White"))
      piece.can_en_passant = true
    elsif piece.type == "King" && start_x == 4 * 80 && (rank == 6 || rank == 2)
      piece.can_castle = true
    end

    # Castle
    if piece.type == "King" && (rank == 6 || rank == 2) && piece.can_castle
      castle(rank, file)
      castle_flag = true
    # Promotion
    elsif piece.type == "Pawn" && (file == 7 || file == 0)
      promotion_ui
      promotion_flag = true
    # En passant
    elsif @last_move && @last_move.color != piece.color && piece.type == "Pawn" && @last_move.type == "Pawn" && @last_move.can_en_passant 
      if (start_x + 80 == piece.x || start_x - 80 == piece.x) && 
        ((start_y + 80 == piece.y && piece.color == "Black") || 
        (start_y - 80 == piece.y && piece.color == "White"))
        
        capture_piece(@clicked_piece, @last_move)
        en_passant_flag = true
      end
    end

    if !castle_flag && !capture_flag && !promotion_flag && !en_passant_flag
      @sounds.move_self.play 
    end
  end
  
  def unmake_move

    # Return if there are no past moves
    return if @move_history_past.empty?
  
    # Get the last moved piece from the history
    piece_to_undo = @move_history_past.pop
    # If there's no piece to undo, return early
    return if piece_to_undo.nil?
  
    # Restore the piece's previous position
    piece_to_undo.render.remove
    piece_to_undo.x = piece_to_undo.pre_x.pop
    piece_to_undo.y = piece_to_undo.pre_y.pop
    piece_to_undo.render_piece
  
    # # Restore captured piece if any
    if piece_to_undo.capture_piece.last
      captured_piece = piece_to_undo.capture_piece.pop
      captured_piece.render_piece
      @pieces.add(captured_piece)
    end
  
    # Reset en passant flag if necessary
    piece_to_undo.can_en_passant = false if piece_to_undo.type == "Pawn"
  
    # Move the undone move to the future history for redo
    @move_history_future << piece_to_undo
  
    # Clear highlights and reset state
    clear_previous_selection(only_moves: false)
    reset_state_after_move
  
    # Switch turn back to the previous player
    @current_turn = @current_turn == "White" ? "Black" : "White"
    @number_of_moves -=1
  end
  

  # TODO: NEED TO BE FIXED
  def remake_move
    return if @pieces.empty? || @move_history_future.nil?
    
    # Store the piece that was last moved
    piece_to_undo = @move_history_future.last
    
    # Revert the piece position to its previous position
    piece_to_undo.render.remove
    piece_to_undo.x = piece_to_undo.pre_x
    piece_to_undo.y = piece_to_undo.pre_y
    piece_to_undo.render_piece
    
    # If there was a capture, restore the captured piece
    if piece_to_undo.capture_piece
      captured_piece = piece_to_undo.capture_piece
      captured_piece.render_piece
      @pieces.add(captured_piece)
      piece_to_undo.capture_piece = nil
    end
    
    # Reset en passant flag if it was set
    piece_to_undo.can_en_passant = false if piece_to_undo.type == "Pawn"
    
    # Clear any highlighted squares or moves
    clear_previous_selection(only_moves: false)
    
    # Reset all states
    reset_state_after_move
    
    # Reset the last move
    @move_history_past << @move_history_future.last
    @move_history_future.delete(@move_history_future.last)
  end

  # Captures the opponent's piece
  def capture_piece(piece, target_piece)
    target_piece.render.remove
    @pieces.delete(target_piece)
    @sounds.capture.play
    piece.capture_piece << target_piece
  end

  def promotion_ui()
    if @clicked_piece.color == "Black"
      # Automatically promote black pawn to Queen
      @clicked_piece.render.remove
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

  def castle(rank, file)
    rook_x = rank == 6 ? 7 * 80 : 0
    rook = @pieces.find { |p| p.type == "Rook" && p.color == @clicked_piece.color && p.x == rook_x && p.is_moved == false}
    rook_new_x = rank == 6 ? 5 * 80 : 3 * 80
    if rook
      # Move rook to its new position
      rook.render.remove
      rook.x = rook_new_x
      rook.render_piece
      rook.is_moved = true
      @sounds.castle.play
    end
  end

  def handle_check(piece, king)
    if piece.type != "King" && king.attacking_pieces.size == 2
      piece.moves.clear
    else
      update_legal_moves(piece, king)
    end
  end

  def handle_pin(piece, king)
    if piece.type != "King" && piece.is_pinned?
      update_legal_moves(piece, king)
    end
  end
  
  def update_legal_moves(piece, king)
    blocking_squares = calculate_blocking_squares(king.position, king.attacking_pieces.first) 
    piece.moves -= illegal_moves(blocking_squares, piece) 
  end

  def illegal_moves(blocking_squares, piece)
    moves_to_delete = []
    if piece.type != "King"
      piece.moves.each do |move|
        if !blocking_squares.include?(move)
          moves_to_delete << move
        else
          @no_legal_moves = false
        end
      end
    end
    return moves_to_delete
  end

  def calculate_blocking_squares(king_pos, attacking_piece)
    blocking_squares = Set.new
    
    # Calculate direction vectors dx and dy

    dx = (attacking_piece.x - king_pos[0]) <=> 0
    dy = (attacking_piece.y - king_pos[1]) <=> 0
    
    # Initialize x and y positions one step away from the king
    x, y = king_pos[0] + dx * 80, king_pos[1] + dy * 80
    count = 0
    
    # Only calculate for non-knight pieces
    if attacking_piece.type == "Knight"
      blocking_squares.add([attacking_piece.rank, attacking_piece.file])
    else
      # Iterate to add each blocking square until reaching the attacking piece
      while [x, y] != [attacking_piece.x + dx * 80, attacking_piece.y + dy * 80]
        break if count == 100  # Prevent infinite loop
        
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
  
  def checkmate_ui()
    @game_over = true
    @sounds.game_end.play
    game_result_ui
    # Winner text
    @game_result.text = "#{@current_turn == "White" ? 'Black' : 'White'} wins by checkmate!"
  end

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
  def render_at_new_pos(rank, file)
    @clicked_piece.is_moved = true
    @clicked_piece.render.remove  
    @clicked_piece.x = rank * 80 
    @clicked_piece.y = file * 80
    @clicked_piece.render_piece
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
  def highlight_selected_piece(x, y)
    clear_previous_selection(only_moves: false)

    @clicked_square = Square.new(
      x: x,
      y: y,
      z: ZOrder::OVERLAP,
      size: 80,
      color: "#B58B37"
    )
    @clicked_square.color.opacity = 0.8
  end
  
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

  def reset_board
    @pieces.each { |piece| piece.render.remove }
    @pieces.clear
    @clicked_square&.remove
    @target_square&.remove
    @moves.each(&:remove)
    @moves.clear
    @last_move = nil
    @current_turn = "White"
    @checked = false
    @valid_moves = nil
    @clicked_piece = nil
    @is_piece_clicked = false
    @game_over = false
    @promotion = false
    @board = initialize_board
    draw_board
  end
end
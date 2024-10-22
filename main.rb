require 'rubygems'
require 'ruby2d'

module ZOrder
  BOARD, OVERLAP, PIECE = *0..2
end

class Sounds
  attr_accessor :capture, :castle, :illegal, :move_check, :move_self, :move_opponent, :game_start, :game_end

  def initialize
    @capture = Music.new("sounds/capture.mp3")
    @castle = Music.new("sounds/castle.mp3")
    @illegal = Music.new("sounds/illegal.mp3")
    @move_check = Music.new("sounds/move_check.mp3")
    @move_self = Music.new("sounds/move_self.mp3")
    @move_opponent = Music.new("sounds/move_opponent.mp3")
    @game_start = Music.new("sounds/game_start.mp3")
    @game_end = Music.new("sounds/game_end.mp3")
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
  piece_type = piece & 0b00111
  case piece_type
  when PieceEval::KING   then "pieces/#{color}k.png"
  when PieceEval::QUEEN  then "pieces/#{color}q.png"
  when PieceEval::ROOK   then "pieces/#{color}r.png"
  when PieceEval::BISHOP then "pieces/#{color}b.png"
  when PieceEval::KNIGHT then "pieces/#{color}n.png"
  when PieceEval::PAWN   then "pieces/#{color}p.png"
  else nil
  end
end

# Class representing a Piece
class Piece
  attr_accessor :x, :y, :piece, :moves, :render, :exist, :game

  def initialize(x, y, piece, piece_image, game, exist = true)
    @x = x
    @y = y
    @piece = piece
    @piece_image = piece_image
    @exist = exist
    @rank = x / 80
    @file = y / 80
    @moves = Array.new()
    @game = game
  end

  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y, z: ZOrder::PIECE, width: 80, height: 80)
  end

  def name
    color + piece_type if piece_type != "No Piece"
  end

  def color()
    @piece & (0b01000 | 0b10000) == 8 ? "White" : "Black"
  end

  def piece_type()
    case @piece & 0b00111
    when PieceEval::KING   then "King"
    when PieceEval::QUEEN  then "Queen"
    when PieceEval::ROOK   then "Rook"
    when PieceEval::BISHOP then "Bishop"
    when PieceEval::KNIGHT then "Knight"
    when PieceEval::PAWN   then "Pawn"
    else "No Piece"
    end
  end

  def generate_moves
    @moves.clear
    case piece_type
    when "King"
      king_moves
    when "Queen", "Rook", "Bishop"
      sliding_moves(piece_type)
    when "Knight"
      knight_moves
    when "Pawn"
      pawn_moves
    end
  end
  
  def king_moves
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    directions.each do |dx, dy|
      new_x = @x/80 + dx
      new_y = @y/80 + dy
      add_move_if_legal(new_x, new_y)
    end
  end
  
  def sliding_moves(piece)
    directions = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
  
    # Determine which direction indices to use based on the piece type
    indices = case piece
              when "Bishop"
                (4..7).to_a  # Diagonal directions
              when "Rook"
                (0..3).to_a  # Straight directions
              when "Queen"
                (0..7).to_a  # All directions
              else
                []           # Handle other cases or raise an error
              end
  
    indices.each do |i|
      x, y = @x/80, @y/80
      loop do
        x += directions[i][0]
        y += directions[i][1]
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
  
  def pawn_moves
    direction = @piece & PieceEval::WHITE > 0 ? -1 : 1 # White moves up, Black moves down
    add_move_if_legal(@x/80, @y/80 + direction) # Forward move
    # Add logic for capturing, double moves, etc.
  end
  
  def add_move_if_legal(new_x, new_y)
    if new_x.between?(0, 7*80) && new_y.between?(0, 7*80) # Check within bounds
      target_piece = @game.pieces.find { |p| p.x == new_x * 80 && p.y == new_y * 80 && p.exist }
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

class Move
  attr_accessor :start_square, :target_square

  def initialize(start_square, target_square)
    @start_square = start_square
    @target_square = target_square
  end
end

class Game
  attr_reader :sounds, :pieces, :squares, :board, :clicked_piece, :clicked_square, :overlap_square

  def initialize
    @sounds = Sounds.new
    @pieces = []
    @squares = []
    @moves = []
    @board = initialize_board
    @is_piece_clicked = false

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
    (0...8).each do |rank|
      (0...8).each do |file|
        is_light_square = (rank + file) % 2 != 0
        square_color = is_light_square ? "#6e4e36" : "#b99b75"

        # Draw square
        square = Square.new(x: rank * 80, y: file * 80, size: 80, z: ZOrder::BOARD, color: square_color)
        @squares << square

        # Get the piece at the current position
        piece_pos = @board[file][rank]
        image_file = piece_image(piece_pos)
        # Create and store the piece object
        if image_file
          piece = Piece.new(rank * 80, file * 80, piece_pos, image_file, self)
          piece.render_piece
          @pieces << piece
        end
        @sounds.game_start.play
      end
    end
  end

  def handle_mouse_click(mouse)
    rank, file = (mouse.x / 80).to_i, (mouse.y / 80).to_i
  
    case mouse.button
    when :left
      @illegal_state = false
      clear_previous_selection if @clicked_square && (@overlap_square || @illegal_state)
      
      if !@is_piece_clicked
        select_piece(rank, file)
      elsif @clicked_piece
        move_piece_or_capture(rank, file)
      end
    end
  end
  
  
  # Clears previous selections and moves if necessary
  def clear_previous_selection
    @clicked_square.remove if @clicked_square
    @overlap_square.remove if @overlap_square
    @moves.each(&:remove)
    @moves.clear
  end
  
  # Selects a piece if one is found at the clicked square
  def select_piece(rank, file)
    @clicked_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 && p.exist }
  
    if @clicked_piece
      @clicked_piece.generate_moves
      highlight_moves(@clicked_piece)
      highlight_selected_piece
      @is_piece_clicked = true
      puts "Clicked #{@clicked_piece.name}"
    end
  end
  
  # Highlights all possible moves for the selected piece
  def highlight_moves(piece)
    piece.moves.each do |move|
      move_circle = Circle.new(x: move[0] * 80 + 40, y: move[1] * 80 + 40, radius: 10, color: 'black', z: ZOrder::OVERLAP)
      target_piece_square = @pieces.find { |p| p.x == move[0] * 80 && p.y == move[1] * 80 && p.exist }
  
      if target_piece_square
        move_circle.radius = 15
        move_circle.color.opacity = 0.5
        move_circle.z = ZOrder::PIECE + 1
      else
        move_circle.color.opacity = 0.4
      end
  
      @moves << move_circle
    end
  end
  
  # Highlights the selected piece on the board
  def highlight_selected_piece
    @clicked_square = Square.new(x: @clicked_piece.x, y: @clicked_piece.y, z: ZOrder::OVERLAP, size: 80, color: "#B58B37")
    @clicked_square.color.opacity = 0.8
  end
  
  # Attempts to move the piece or capture an opponent piece
  def move_piece_or_capture(rank, file)
    target_move = [rank, file]

    # Check if the target move is in the list of legal moves
    if not @clicked_piece.moves.include?(target_move)
      handle_illegal_move
      @clicked_square.color = 'red'
      return
    end
  
    target_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 && p.exist }
    @illegal_state = false
  
    if target_piece
      if target_piece.color == @clicked_piece.color
        handle_illegal_move
      else
        capture_piece(target_piece)   # Capture the piece and play the capture sound
        move_piece(rank, file)        # Move the selected piece after the capture
      end
    else
      move_piece(rank, file)          # Normal move
    end
  
    reset_state_after_move unless @illegal_state
  end
  
  
  # Handles illegal move (e.g., trying to move to a square with a piece of the same color)
  def handle_illegal_move
    @sounds.illegal.play
    @clicked_piece.moves.clear
    @illegal_state = true
  end
  
  # Captures the opponent's piece
  def capture_piece(target_piece, rank, file)
    target_piece.render.remove
    target_piece.exist = false
    # Move the clicked piece to the new coordinates
    @clicked_piece.render.remove
    @clicked_piece.x = rank * 80  # Update the x position
    @clicked_piece.y = file * 80  # Update the y position
    @clicked_piece.render_piece    # Re-render the piece in the new position
    puts "Moved #{@clicked_piece.name} piece to (#{file}, #{rank})"
    @sounds.capture.play
  end
  
  # Moves the selected piece to the new square
  def move_piece(rank, file)
    @sounds.move_self.play
  
    # Draw the square indicating the piece has moved
    @overlap_square = Square.new(x: rank * 80, y: file * 80, z: ZOrder::OVERLAP, size: 80, color: "#B58B37")
    @overlap_square.color.opacity = 0.8
  
    # Move the clicked piece to the new coordinates
    @clicked_piece.render.remove
    @clicked_piece.x = rank * 80  # Update the x position
    @clicked_piece.y = file * 80  # Update the y position
    @clicked_piece.render_piece    # Re-render the piece in the new position
  
    puts "Moved #{@clicked_piece.name} piece to (#{file}, #{rank})"
  end
  
  # Resets the state after the move is completed
  def reset_state_after_move
    @is_piece_clicked = false
    @clicked_piece = nil
  end
  
  
end

# Window settings
set width: 640, height: 640

# Initialize Game
game = Game.new

on :mouse_down do |mouse|
  game.handle_mouse_click(mouse)
end

show

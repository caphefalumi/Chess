require 'rubygems'
require 'ruby2d'

module ZOrder
  BOARD, OVERLAP, PIECE = *0..2
end

class Sounds 
  attr_accessor :capture, :castle, :illegal, :move_check, :move_self, :move_opponent, :game_start, :game_end
  def initialize()
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

class Board
end

module Piece_val
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
  color = piece & Piece_val::WHITE != 0 ? "w" : "b"
  case piece & ~Piece_val::WHITE & ~Piece_val::BLACK
  when Piece_val::KING   then "pieces/#{color}k.png"
  when Piece_val::QUEEN  then "pieces/#{color}q.png"
  when Piece_val::ROOK   then "pieces/#{color}r.png"
  when Piece_val::BISHOP then "pieces/#{color}b.png"
  when Piece_val::KNIGHT then "pieces/#{color}n.png"
  when Piece_val::PAWN   then "pieces/#{color}p.png"
  else nil
  end
end

# Class representing a Piece
class Piece
  attr_accessor :x, :y, :piece, :render, :exist

  def initialize(x, y, piece, piece_image, exist = true)
    @x = x
    @y = y
    @piece = piece
    @piece_image = piece_image
    @exist = exist
  end
  def render_piece()
    @render = Image.new(@piece_image, x: @x, y: @y , z: ZOrder::PIECE, width: 80, height: 80, )
  end

  # Method to get the name and color of the piece
  def name
    base_piece = @piece & ~Piece_val::WHITE & ~Piece_val::BLACK
    color = @piece & Piece_val::WHITE != 0 ? "White" : "Black"
    case base_piece
    when Piece_val::KING   then "#{color}King"
    when Piece_val::QUEEN  then "#{color}Queen"
    when Piece_val::ROOK   then "#{color}Rook"
    when Piece_val::BISHOP then "#{color}Bishop"
    when Piece_val::KNIGHT then "#{color}Knight"
    when Piece_val::PAWN   then "#{color}Pawn"
    else "No Piece"
    end
  end
end

# Initial board position
board_pos = [
  [Piece_val::ROOK | Piece_val::WHITE, Piece_val::KNIGHT | Piece_val::WHITE, Piece_val::BISHOP | Piece_val::WHITE, Piece_val::QUEEN | Piece_val::WHITE, Piece_val::KING | Piece_val::WHITE, Piece_val::BISHOP | Piece_val::WHITE, Piece_val::KNIGHT | Piece_val::WHITE, Piece_val::ROOK | Piece_val::WHITE],
  [Piece_val::PAWN | Piece_val::WHITE] * 8,
  [Piece_val::NONE] * 8,
  [Piece_val::NONE] * 8,
  [Piece_val::NONE] * 8,
  [Piece_val::NONE] * 8,
  [Piece_val::PAWN | Piece_val::BLACK] * 8,
  [Piece_val::ROOK | Piece_val::BLACK, Piece_val::KNIGHT | Piece_val::BLACK, Piece_val::BISHOP | Piece_val::BLACK, Piece_val::QUEEN | Piece_val::BLACK, Piece_val::KING | Piece_val::BLACK, Piece_val::BISHOP | Piece_val::BLACK, Piece_val::KNIGHT | Piece_val::BLACK, Piece_val::ROOK | Piece_val::BLACK]
]


def load_position_from_fen(fen)
  pieceTypeFromSymbol
end

# Create a list to store all pieces
pieces = []
squares = []
# Window settings
set width: 640, height: 640
sounds = Sounds.new()
# Drawing the board and placing the pieces
for rank in 0...8
  for file in 0...8
    isLightSquare = (file + rank) % 2 != 0
    square_color = isLightSquare ? "#b99b75" : "#6e4e36"

    # Draw square
    square = Square.new(x: file * 80, y: rank * 80, size: 80, z: ZOrder::BOARD, color: square_color)
    squares << square
    # Get the piece at the current position
    piece_pos = board_pos[rank][file]
    image_file = piece_image(piece_pos)

    # Create and store the piece object
    if image_file

      piece = Piece.new(file * 80, rank * 80, piece_pos, image_file)
      piece.render_piece
      pieces << piece

    end
    sounds.game_start.play()
  end
end


# Function to capture piece based on mouse click
clicked_piece = nil
selected_piece = nil
clicked_square = nil 
overlap_square = nil

on :mouse_down do |mouse|
  file = (mouse.x / 80).to_i  # Convert mouse click to file
  rank = (mouse.y / 80).to_i  # Convert mouse click to rank
  

  case mouse.button
  when :left
    # Select a piece if it's present at the clicked position
    if clicked_square && overlap_square 
      clicked_square.remove 
      overlap_square.remove
    end
    clicked_piece = pieces.find { |p| p.x == file * 80 && p.y == rank * 80 && p.exist}
    if clicked_piece
      old_pos_x = clicked_piece.x
      old_pos_y = clicked_piece.y
      clicked_square = Square.new(x: clicked_piece.x, y: clicked_piece.y, z:ZOrder::OVERLAP, size:80, color: "#B58B37")
      clicked_square.color.opacity = 0.8
      puts "Clicked #{clicked_piece.name}"
    end
  when :right
    # Move the selected piece to the clicked position
    if clicked_piece 
      overlap_piece = pieces.find { |p| p.x == file * 80 && p.y == rank * 80 && p.exist}
      overlap_piece.render.remove if overlap_piece
      if overlap_piece 
        overlap_piece.exist = false
        sounds.capture.play()
      else 
        sounds.move_self.play()
      end

      overlap_square = Square.new(x: file * 80, y: rank * 80, z:ZOrder::OVERLAP, size:80, color: "#B58B37")
      overlap_square.color.opacity = 0.8
      clicked_piece.render.remove # Remove the old image
      clicked_piece.x = file * 80
      clicked_piece.y = rank * 80
      clicked_piece.render_piece() # Render the piece at the new position

      puts "Moving piece to (#{file}, #{rank})"
      clicked_piece = nil
      selected_piece = nil
    end
  end
end

show

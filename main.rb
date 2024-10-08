require 'rubygems'
require 'ruby2d'


module ZOrder
  BOARD, PIECE= *0..1
end

class Board

end
module Piece
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

piece_pos = [
  [Piece::ROOK | Piece::WHITE, Piece::KNIGHT | Piece::WHITE, Piece::BISHOP | Piece::WHITE, Piece::QUEEN | Piece::WHITE, Piece::KING | Piece::WHITE, Piece::BISHOP | Piece::WHITE, Piece::KNIGHT | Piece::WHITE, Piece::ROOK | Piece::WHITE],
  [Piece::PAWN | Piece::WHITE] * 8,
  [Piece::NONE] * 8,
  [Piece::NONE] * 8,
  [Piece::NONE] * 8,
  [Piece::NONE] * 8,
  [Piece::PAWN | Piece::BLACK] * 8,
  [Piece::ROOK | Piece::BLACK, Piece::KNIGHT | Piece::BLACK, Piece::BISHOP | Piece::BLACK, Piece::QUEEN | Piece::BLACK, Piece::KING | Piece::BLACK, Piece::BISHOP | Piece::BLACK, Piece::KNIGHT | Piece::BLACK, Piece::ROOK | Piece::BLACK]
]

class Piece
  attr_accessor :x, :y, :piece
  def initialize(x, y, piece)
    @x = x
    @y = y
    @piece = piece
  end
end
# Helper function to return image file path based on piece
def piece_image(piece, rank)
  color = piece & Piece::WHITE != 0 ? "w" : "b"
  case piece & ~Piece::WHITE & ~Piece::BLACK
  when Piece::KING   then "pieces/#{color}k.png"
  when Piece::QUEEN  then "pieces/#{color}q.png"
  when Piece::ROOK   then "pieces/#{color}r.png"
  when Piece::BISHOP then "pieces/#{color}b.png"
  when Piece::KNIGHT then "pieces/#{color}n.png"
  when Piece::PAWN   then "pieces/#{color}p.png"
  else nil
  end
end
set width: 640, height: 640

# Drawing the board
for rank in 0...8
  for file in 0...8
    isLightSquare = (file + rank) % 2 != 0
    square_color = isLightSquare ? "#b99b75" : "#6e4e36"

    # Draw square
    Square.new(x: file * 80, y: rank * 80, size: 80, z: ZOrder::BOARD, color: square_color)

    # Get the piece at the current position
    piece = piece_pos[rank][file]
    image_file = piece_image(piece, rank)

    # If there's a piece, draw it
    if image_file
      Image.new(image_file, x: file * 80, y: rank * 80, width: 80, height: 80, z: ZOrder::PIECE)
    end
  end
end

on :mouse_down do |mouse|
  # x and y coordinates of the mouse
  puts mouse.x, mouse.y

  # Read the button mouse
  case mouse.button
  when :left
    
  when :middle
    # Middle mouse button pressed down
  when :right
    # Right mouse button pressed down
  end
end
show 
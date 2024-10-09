require 'rubygems'
require 'ruby2d'

module ZOrder
  BOARD, PIECE = *0..1
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
  attr_accessor :x, :y, :piece, :render

  def initialize(x, y, piece, piece_image)
    @x = x
    @y = y
    @piece = piece
    @piece_image = piece_image
  end
  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y , width: 80, height: 80, z: ZOrder::PIECE)
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

# Create a list to store all pieces
pieces = []

# Window settings
set width: 640, height: 640

# Drawing the board and placing the pieces
for rank in 0...8
  for file in 0...8
    isLightSquare = (file + rank) % 2 != 0
    square_color = isLightSquare ? "#b99b75" : "#6e4e36"

    # Draw square
    Square.new(x: file * 80, y: rank * 80, size: 80, z: ZOrder::BOARD, color: square_color)

    # Get the piece at the current position
    piece_pos = board_pos[rank][file]
    image_file = piece_image(piece_pos)

    # Create and store the piece object
    if image_file

      piece = Piece.new(file * 80, rank * 80, piece_pos, image_file)
      piece.render_piece
      pieces << piece

      # Draw the piece
    end
  end
end

# Function to capture piece based on mouse click
selected_piece = nil

on :mouse_down do |mouse|
  file = (mouse.x / 80).to_i  # Convert mouse click to file
  rank = (mouse.y / 80).to_i  # Convert mouse click to rank

  case mouse.button
  when :left
    # Select a piece if it's present at the clicked position
    clicked_piece = pieces.find { |p| p.x == file * 80 && p.y == rank * 80 }
    if clicked_piece
      @selected_piece = clicked_piece
      @selected_piece.x = mouse.x
      @selected_piece.y = mouse.y
      
    else
      puts "No piece selected."
    end
  when :right
    # Move the selected piece to the clicked position
    if selected_piece
      puts "Moving piece to (#{file}, #{rank})"
      @selected_piece.x = file * 80
      @selected_piece.y = rank * 80
      @selected_piece
    end
  end
end
# on :mouse_move do |event|
#   # Change in the x and y coordinates
#   if @selected_piece
#     @selected_piece.x = event.x
#     @selected_piece.y = event.y
#     @selected_piece.render()
#   end
# end
show
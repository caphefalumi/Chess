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
  color = piece & PieceEval::WHITE != 0 ? "w" : "b"
  case piece & ~PieceEval::WHITE & ~PieceEval::BLACK
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
  attr_accessor :x, :y, :piece_pos, :render, :exist

  def initialize(x, y, piece_pos, piece_image, exist = true)
    @x = x
    @y = y
    @piece_pos = piece_pos
    @piece_image = piece_image
    @exist = exist
  end

  def render_piece
    @render = Image.new(@piece_image, x: @x, y: @y, z: ZOrder::PIECE, width: 80, height: 80)
  end

  def name
    piece_type = @piece_pos & 0b00111
    color = @piece_pos & (0b01000 | 0b10000) == 8 ? "White" : "Black"
    case piece_type
    when PieceEval::KING   then "#{color}King"
    when PieceEval::QUEEN  then "#{color}Queen"
    when PieceEval::ROOK   then "#{color}Rook"
    when PieceEval::BISHOP then "#{color}Bishop"
    when PieceEval::KNIGHT then "#{color}Knight"
    when PieceEval::PAWN   then "#{color}Pawn"
    else "No Piece"
    end
  end

  def color()
    @piece_pos & (0b01000 | 0b10000) == 8 ? "White" : "Black"
  end

  def piece_type(piece)
    piece & 0b00111
  end

  def IsRookOrQueen(piece)
    (piece & 0b110) == 0b110
  end

  def IsBishopOrQueen(piece)
    (piece & 0b101) == 0b101
  end

  def IsSlidingPiece(piece)
    (piece & 0b100) != 0
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
  attr_reader :sounds, :pieces, :squares, :board_pos, :clicked_piece, :clicked_square, :overlap_square

  def initialize
    @sounds = Sounds.new
    @pieces = []
    @squares = []
    @board_pos = initialize_board
    @is_piece_clicked = false
    draw_board
  end

  def initialize_board
    [
      [PieceEval::ROOK | PieceEval::WHITE, PieceEval::KNIGHT | PieceEval::WHITE, PieceEval::BISHOP | PieceEval::WHITE, PieceEval::QUEEN | PieceEval::WHITE, PieceEval::KING | PieceEval::WHITE, PieceEval::BISHOP | PieceEval::WHITE, PieceEval::KNIGHT | PieceEval::WHITE, PieceEval::ROOK | PieceEval::WHITE],
      [PieceEval::PAWN | PieceEval::WHITE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::NONE] * 8,
      [PieceEval::PAWN | PieceEval::BLACK] * 8,
      [PieceEval::ROOK | PieceEval::BLACK, PieceEval::KNIGHT | PieceEval::BLACK, PieceEval::BISHOP | PieceEval::BLACK, PieceEval::QUEEN | PieceEval::BLACK, PieceEval::KING | PieceEval::BLACK, PieceEval::BISHOP | PieceEval::BLACK, PieceEval::KNIGHT | PieceEval::BLACK, PieceEval::ROOK | PieceEval::BLACK]
    ]
  end

  def draw_board
    (0...8).each do |rank|
      (0...8).each do |file|
        is_light_square = (rank + file) % 2 != 0
        square_color = is_light_square ? "#b99b75" : "#6e4e36"

        # Draw square
        square = Square.new(x: rank * 80, y: file * 80, size: 80, z: ZOrder::BOARD, color: square_color)
        @squares << square

        # Get the piece at the current position
        piece_pos = @board_pos[file][rank]
        image_file = piece_image(piece_pos)
        # Create and store the piece object
        if image_file
          piece = Piece.new(rank * 80, file * 80, piece_pos, image_file)
          piece.render_piece
          @pieces << piece
        end
        @sounds.game_start.play
      end
    end
  end

  def handle_mouse_click(mouse)
    rank = (mouse.x / 80).to_i  # Convert mouse click to file
    file = (mouse.y / 80).to_i  # Convert mouse click to rank
  
    case mouse.button
    when :left

      if @clicked_square && @overlap_square
        @clicked_square.remove
        @overlap_square.remove
      end
  
      if !@is_piece_clicked
        @clicked_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 && p.exist }
      end
      if @clicked_piece
        if !@is_piece_clicked
          # First click: Select the piece
          @clicked_square = Square.new(x: @clicked_piece.x, y: @clicked_piece.y, z: ZOrder::OVERLAP, size: 80, color: "#B58B37")
          @clicked_square.color.opacity = 0.8
          @is_piece_clicked = true
          puts "Clicked #{@clicked_piece.name}"
        else
          # Second click: Try to move the piece
          overlap_piece = @pieces.find { |p| p.x == rank * 80 && p.y == file * 80 && p.exist }
          
          if overlap_piece
            #Capture 
            overlap_piece.render.remove
            overlap_piece.exist = false
            @sounds.capture.play
          else
            #Move
            @sounds.move_self.play
          end
  
          # Draw color on overlap square
          @overlap_square = Square.new(x: rank * 80, y: file * 80, z: ZOrder::OVERLAP, size: 80, color: "#B58B37")
          @overlap_square.color.opacity = 0.8
          
          # Render at the new pos of overlap piece
          @clicked_piece.render.remove
          @clicked_piece.x = rank*80
          @clicked_piece.y = file*80
          @clicked_piece.render_piece
          
          puts "Moved #{@clicked_piece.name} piece to (#{file}, #{rank})"
          
          # Reset the state after the move
          @is_piece_clicked = false
          @clicked_piece = nil
        end
      end
    end
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

require 'ruby2d'
require_relative 'board'
require_relative 'chess_engine'
set width: 640, height: 640

set title: "Chess"

# Initialize Game
board = Board.new
engine = Engine.new(board)
on :mouse_down do |mouse|
  board.handle_mouse_click(mouse)
end

on :key_down do |event|
  if event.key == 'z'
    board.unmake_move
  elsif event.key == 'y'
    board.remake_move
  elsif event.key == 'r'
    board.reset_board
  elsif event.key == 'd'
    moves = board.get_moves()
    moves.each do |move|
      puts move[:to].inspect
    end
  elsif event.key == "e"
    king = board.pieces.find { |p| p.type == "King" && p.color == board.current_turn }
    king.generate_moves
    board.make_move(king, 4, 4)
    puts engine.evaluate("White")
    puts [king.rank, king.file].inspect
    board.unmake_move
    puts king.rank
    puts king.file
  elsif event.key == 'p'
    close
  end
end
show
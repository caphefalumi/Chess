require 'ruby2d'
require_relative 'board'
require_relative 'chess_engine'
set width: 640, height: 640

set title: "Chess"

# Initialize Game
board = Board.new
on :mouse_down do |mouse|
  board.handle_mouse_click(mouse)
end

on :key_down do |event|
  if event.key == 'z'
    board.unmake_move
  elsif event.key == 'y'
    board.pieces.each do |piece|
      piece.render_piece
    end
  elsif event.key == 'r'
    board.reset_board
  elsif event.key == 'd'
    moves = board.get_moves()
    moves.each do |move|
      puts "#{move[:piece].name} #{move[:from].inspect} #{move[:to].inspect}"
    end
    board.unmake_move()
    moves = board.get_moves()
    moves.each do |move|
      puts "#{move[:piece].name} #{move[:from].inspect} #{move[:to].inspect}"
    end
  elsif event.key == 'p'
    close
  end
end
show
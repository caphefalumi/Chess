require 'ruby2d'
require_relative 'board'
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
  end
end
show
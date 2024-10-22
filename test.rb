require "ruby2d"
# Window settings
set width: 640, height: 640

# Initialize Game


image = Image.new(
  'pieces\images.jpg',
  x: 0, y: 0,
  width: 800, height: 800,
  color: [1.0, 0.5, 0.2, 1.0],
  rotate: 90,
  z: 10
)
image2 = Image.new(
  'pieces\images.jpg',
  x: -800, y: 0,
  width: 800, height: 800,
  color: [1.0, 0.5, 0.2, 1.0],
  rotate: 90,
  z: 10
)
update do 
  image.x+=2
  image2.x+=2
  if image.x == 700
    puts "ok"
    image.x=0
  end
  if image2.x==700
    image2.x=-800
  end
end
show

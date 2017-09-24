require 'pry'
require 'chunky_png'
class X
  attr_reader :min, :max
  def self.[] min, max
    X.new min, max
  end
  def initialize min, max
    @min, @max = min, max
  end
  def + v
    if X === v
      X.new min+v.min, max+v.max
    else
      X.new min+v, max+v
    end
  end
  def - v
    if X === v
      X.new min+v.min, max+v.max
    else
      X.new min-v, max-v
    end
  end
  def * v
    return X.new(*[min*v, max*v].minmax) unless X === v
    if min*max<0&&v.min*v.max<0
      X.new(*[0, min*v.min, max*v.max, min*v.max, max*v.min].minmax)
    else
      X.new(*[min*v.min, max*v.max, min*v.max, max*v.min].minmax)
    end
  end
  def abs
    if min*max < 0
      X.new 0, [min.abs, max.abs].max
    else
      X.new(*[min.abs, max.abs].minmax)
    end
  end
  def ** n
    if min*max<0
      X.new(*[0, min**n, max**n].minmax)
    else
      X.new(*[min**n, max**n].minmax)
    end
  end
  def sqrt
    X.new min<0 ? 0 : Math.sqrt(min), max<0 ? 0 : Math.sqrt(max)
  end
end
class Numeric; def sqrt; Math.sqrt self; end; end


def norm x, y, z
  d=1e-6
  dx = shape(x+d,y,z)-shape(x-d,y,z)
  dy = shape(x,y+d,z)-shape(x,y-d,z)
  dz = shape(x,y,z+d)-shape(x,y,z-d)
  dr = (dx**2+dy**2+dz**2)**0.5
  [dx/dr, dy/dr, dz/dr]
end


def trace cx, cy, d=0
  x0, y0, z0 = 0, 0, 6
  dx, dy, dz = X[cx,cx+d], X[cy,cy+d], -2

  find = lambda do |min, max|
    range = X[min, max]
    x = range*dx+x0
    y = range*dy+y0
    z = range*dz+z0
    s = shape(x, y, z)
    return min if s.max <= 0
    return min if s.min <= 0 && max-min<1e-10
    return if s.min > 0
    find.(min, (min+max)/2) || find.((min+max)/2, max)
  end
  find.(0.0, 6.0)
end

size = 64
img = ChunkyPNG::Image.new size, size
skipmap = {}
skip=8
(size/skip).times do |ix|
  (size/skip).times do |iy|
    skipmap[[ix,iy]] = trace 2.0*(skip*ix)/size-1, 2.0*(skip*iy)/size-1, 2.0*skip/size
  end
end
size.times do |ix|
  p ix
  size.times do |iy|
    next unless skipmap[[ix/skip,iy/skip]]
    dist = trace 2.0*ix/size-1, 2.0*iy/size-1
    dist||=0
    img[ix, iy] = (dist*256 % 256).round*0x1010101
  end
end
img.save 'out.png'
# binding.pry
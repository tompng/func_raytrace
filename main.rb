require 'pry'
require 'chunky_png'
begin
  require './func.rb'
rescue LoadError
  def shape x, y, z
    x**4+y**4+z**4+x**3-y**2+x*y*3+x*z*4-z*y*2+z**3
  end
end

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
  def mid
    (min+max)/2
  end
  def - v
    if X === v
      X.new min-v.max, max-v.min
    else
      X.new min-v, max-v
    end
  end
  def * v
    return X.new(*[min*v, max*v].minmax) unless X === v
    X.new(*[min*v.min, max*v.max, min*v.max, max*v.min].minmax)
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
  x0, y0, z0 = -2, -3, 5
  dx, dy, dz = X[cx,cx+d], X[cy,cy+d], X[-2,-2]
  rotx = Math.atan2((x0**2+y0**2)**0.5, z0)
  rotz = Math::PI+Math.atan2(x0, y0)
  xcos, xsin = Math.cos(rotx), Math.sin(rotx)
  zcos, zsin = Math.cos(rotz), Math.sin(rotz)
  dy, dz = dy*xcos-dz*xsin, dz*xcos+dy*xsin
  dx, dy = dx*zcos+dy*zsin, dy*zcos-dx*zsin

  find = lambda do |min, max|
    range = X[min, max]
    x = range*dx+x0
    y = range*dy+y0
    z = range*dz+z0
    s = shape(x, y, z)
    return range.mid if s.max <= 0
    return range.mid if s.min <= 0 && max-min<1e-10
    return if s.min > 0
    find.(range.min, range.mid) || find.(range.mid, range.max)
  end
  dist = find.(0.0, 6.0)
  [dist, x0+dx.mid*dist, y0+dy.mid*dist, z0+dz.mid*dist] if dist
end

size = 512
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
    dist, x, y, z = trace 2.0*ix/size-1, 2.0*iy/size-1
    next unless dist
    nx,ny,nz = norm x,y,z
    color = (nx*0.1-ny*0.3+nz*0.6+1)/2
    color = 0.5 if color < 0.5
    img[ix, size-iy-1] = (color*256 % 256).round*0x1010101
  end
end
img.save 'out.png'

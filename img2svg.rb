require 'set'
require 'pry'
require 'chunky_png'

def extract_paths img
  w, h = img.width, img.height
  arr = w.times.map{h.times.map{nil}}
  w.times{|x|h.times{|y|
    arr[x][y] = yield(img[x,y]&0xff)
  }}

  startlist=[]
  (1...w).each{|x|(1...h).each{|y|
    startlist << [x, y] if arr[x][y]&&!arr[x-1][y]
  }}
  used = Set.new
  extract = ->x,y{
    path = [[x,y]]
    dirs = [[-1,0], [0,-1], [1,0], [0,1]]
    dir = 0
    cnt=0
    loop do
      ax,ay = dirs[(dir-1)%4]
      adj = arr[x+ax][y+ay]
      break if cnt==8
      unless adj
        dir = (dir-1)%4
        cnt+=1
        next
      end
      ex, ey = dirs[dir]
      if arr[x+ax+ex][y+ay+ey]
        x+=ax+ex
        y+=ay+ey
        path << [x,y]
        dir=(dir+1)%4
        cnt=0
      else
        x+=ax
        y+=ay
        path << [x,y]
        arr[x][y]=1
        cnt=0
      end
      break if path.last == path.first
    end
    path.each { |xy| used << xy }
    path
  }
  paths = []
  startlist.each do |x,y|
    next if used.include? [x, y]
    paths << extract.call(x,y)
  end
  paths
end

def coords2bezier coords
  dirs = coords.size.times.map{|i|
    xa, ya = coords[i-1]
    xb, yb = coords[(i+1)%coords.size]
    dx = xb - xa
    dy = yb - ya
    dr = (dx**2+dy**2)**0.5
    [dx/dr, dy/dr]
  }
  idx=0
  bezier = []
  check = lambda do |idx, len|
    x0, y0 = coords[idx]
    x1, y1 = coords[(idx+len)%coords.size]
    dx0, dy0 = dirs[idx]
    dx1, dy1 = dirs[(idx+len)%coords.size]
    binding.pry if x0.nil?
    lx = x1-x0
    ly = y1-y0
    s = (lx*dy1-dx1*ly) / (dx0*dy1-dy0*dx1)
    px = x0+dx0*s
    py = y0+dy0*s
    if s.nan?
      px = (x0+x1)/2
      py = (y0+y1)/2
    end
    result = [[px, py], [x1, y1]]
    test = ->i{
      x, y = coords[(idx+i)%coords.size]
      t = i.fdiv len
      ax = x0*(1-t)**2+2*t*(1-t)*px+t*t*x1
      ay = y0*(1-t)**2+2*t*(1-t)*py+t*t*y1
      (ax-x)**2+(ay-y)**2 < 2
    }
    return result if (1...len).all? &test
  end
  loop do
    len = 1
    result = check[idx, len]
    loop do
      nextlen = [len*2, coords.size-idx].min
      break unless tmp = check[idx, nextlen]
      result = tmp
      break if len == nextlen
      len = nextlen
    end
    bezier << "Q #{result.map{|p|p.map(&:round).join(' ')}.join(', ')}"
    idx += len
    break if idx == coords.size
  end
  "M #{coords[0].join(' ')} #{bezier.join(' ')} z"
end
def smooth coords
  tmp = coords.dup
  10.times do
    coords.each_with_index do |(x, y), i|
      (xa, ya) = tmp[i-1]
      (xb, yb) = tmp[(i+1)%coords.size]
      dx = (xa+xb)/2.0 - x
      dy = (ya+yb)/2.0 - y
      dr=(dx**2+dy**2)**0.5
      rmax=1
      if dr>rmax
        dx *= rmax/dr
        dy *= rmax/dr
      end
      tmp[i] = [x+dx, y+dy]
    end
  end
  tmp
end

def svg_create file, size
  fills = []
  add = lambda do |color, paths|
    lines = paths.map do |coords|
      next if coords.size < 3
      coords = smooth coords
      p coords.size
      'M' + coords.map { |pos| "%.2f %.2f" % pos }.join(', L ') + ' z'
      coords2bezier coords
    end
    fills << %(<path fill="#{color}" d="#{lines.compact.join("\n")}" />)
  end

  yield add
  File.write file, %(
    <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}">
      #{fills.join("\n")}
    </svg>
  )
end

image = ChunkyPNG::Image.from_file 'out.png'
svg_create 'out.svg', image.width do |proc|
  16.times do |a|
    threshold=16*a
    color = '#'+threshold.to_s(16)*3
    paths = extract_paths(image){|c|c>threshold}
    proc.call color, paths
  end
end

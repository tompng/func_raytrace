require 'set'
require 'pry'
require 'chunky_png'

def extract_path img
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

def smooth path
  tmp = path.dup
  20.times do
    path.each_with_index do |(x, y), i|
      (xa, ya) = tmp[i-1]
      (xb, yb) = tmp[(i+1)%path.size]
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
    lines = paths.map do |path|
      next if path.size < 3
      path = smooth path
      p path.size
      coords = path.map { |pos| "%.2f %.2f" % pos }
      'M' + coords.join(', L ') + ' z'
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
    proc.call '#'+a.to_s(16)*3, extract_path(image){|c|c>a*16}# && c<=(a+1)*16}
  end
  # proc.call '#444', extract_path(image){|c|c>0x40}
  # proc.call '#888', extract_path(image){|c|c>0x80}
  # proc.call '#ccc', extract_path(image){|c|c>0xc0}
end

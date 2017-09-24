require 'pry'
require 'chunky_png'

def extract_path img, threshold
  w, h = img.width, img.height
  arr = w.times.map{h.times.map{nil}}
  w.times{|x|h.times{|y|
    arr[x][y] = 0 if img[x,y]&0xff > threshold
  }}

  startlist=[]
  (1...w).each{|x|(1...h).each{|y|
    startlist << [x, y] if arr[x][y]==0&&!arr[x-1][y]
  }}
  extract = ->x,y{
    path = [[x,y]]
    arr[x][y]=1
    dirs = [[-1,0], [0,-1], [1,0], [0,1]]
    dir = 0
    cnt=0
    loop do
      ax,ay = dirs[(dir-1)%4]
      adj = arr[x+ax][y+ay]
      break if cnt==8
      if adj.nil?
        dir = (dir-1)%4
        cnt+=1
      elsif adj==0
        ex, ey = dirs[dir]
        if arr[x+ax+ex][y+ay+ey]
          x+=ax+ex
          y+=ay+ey
          path << [x,y]
          arr[x][y]=1
          dir=(dir+1)%4
          cnt=0
        else
          x+=ax
          y+=ay
          path << [x,y]
          arr[x][y]=1
          cnt=0
        end
      else
        break
      end
    end
    path
  }
  paths = []
  startlist.each do |x,y|
    next unless arr[x][y]==0
    paths << extract.call(x,y)
  end
  paths
end

def smooth path
end

def paths2svg size, paths
  paths.each { |path| p path.size; smooth path }
  fills = paths.map do |path|
    d = path.each_with_index.map{|(x,y),i|
      (i==0 ? 'M' : 'L')+" #{x} #{y}, "
    }.each_slice(10).map(&:join).join("\n")
    %(<path stroke="black" fill="none" d="#{d} z"/>)
  end
  File.write 'out.svg', %(
    <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}">
      #{fills.join("\n")}
    </svg>
  )
end

image = ChunkyPNG::Image.from_file 'out.png'
paths = extract_path image, 0x80
paths += extract_path image, 0x1
paths += extract_path image, 0x40
paths += extract_path image, 0xc0
paths2svg image.width, paths

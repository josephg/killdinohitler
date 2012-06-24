TAU = Math.PI * 2


TILE_SIDE = 64
TILE_SIDE2 = TILE_SIDE/2
dt = 16

DINO_COUNT = 20

toTile = (x) -> Math.floor(x / TILE_SIDE)

map = null

setMap = (m) -> map = m

players = {}
bullets = []

# Sparse layers map from [x,y] -> value
expandSparseLayer = (sparse, width, height) ->
  result = []

  for x in [0...width]
    row = []
    result.push row
    for y in [0...height]
      row[y] = sparse[[x,y]]

  result

expandMap = (gmap) ->
  m = {width:gmap.width, height:gmap.height, layers:{ground:gmap.layers.ground}}
  m.layers.player = []
  m.layers.shadow = expandSparseLayer gmap.layers.shadow, gmap.width, gmap.height
  m.layers.scenery = expandSparseLayer gmap.layers.scenery, gmap.width, gmap.height
  m

dist2 = (a, b) ->
  dx = a.x - b.x
  dy = a.y - b.y
  dx * dx + dy * dy

within = (a, b, dist) ->
  dist2(a, b) < dist * dist

shoot = (p, angle) ->
  p = players[p] unless typeof p is 'object' # shoot(id, angle) or shoot(player, angle)
  p.ammo--
  bullets.push {x:p.x, y:p.y, angle:angle, age:0, p}

collision =
  'rock':true
  'tree':true
  'barrel':true
  'crate':true

  'top': (x,y) -> y > 0
  'topleft': (x,y) -> x > 0 and y > 0
  'topright': (x, y) -> x < 0 and y > 0
  'left': (x, y) ->
    x > 0
  'right': (x, y) ->
    x < 0

  'rfront': true
  'rleft': (x, y) -> x > 0
  'rright': (x, y) -> x < 0
  'rwindow': true
  'rflag1': true
  'rflag2': true

  'pfront': true
  'pleft': (x, y) -> x > 0
  'pright': (x, y) -> x < 0
  'pwindow': true
  'pflag1': true
  'pflag2': true

# Is the specified point enterable?
canEnterXY = (x, y) ->
  [tx, ty] = [toTile(x), toTile(y)]
  return false unless 0 <= tx < map.width and 0 <= ty < map.height

  scenery = map.layers.scenery[tx][ty]
  c = collision[scenery]

  return true unless c
  return false if c is true
  # c is a function
  return !c(x - tx * TILE_SIDE - TILE_SIDE2, y - ty * TILE_SIDE - TILE_SIDE2)

# Can a player enter the given space
canEnter = (x, y) ->
  ts2 = TILE_SIDE / 2
  #(canEnter (toTile x), (toTile y))# and (canEnter (toTile x), (toTile y + TILE_SIDE))
  (canEnterXY x-ts2, y) and (canEnterXY x+ts2, y) and (canEnterXY x-ts2, y+ts2) and (canEnterXY x+ts2, y+ts2)

removePlayerFromGrid = (p) ->
  console.warn 'Unit not in space' unless p in map.layers.player[toTile p.x]?[toTile p.y]
  map.layers.player[toTile p.x][toTile p.y] = (pl for pl in map.layers.player[toTile p.x][toTile p.y] when pl isnt p)

addPlayerToGrid = (p) ->
  ((map.layers.player[toTile p.x] ||= [])[toTile p.y] ||= []).push p

setPlayerPos = (p, newx, newy) ->
  removePlayerFromGrid p
  p.x = newx
  p.y = newy
  addPlayerToGrid p

BSPEED = 60

# Shared between server and client
commonUpdate = (gotHit) ->
  for id, p of players      
    if p.dx or p.dy
      newx = p.x + p.dx * p.speed
      newy = p.y + p.dy * p.speed

      newx = p.x unless canEnter newx, p.y
      newy = p.y unless canEnter newx, newy

      if newx isnt p.x or newy isnt p.y
        setPlayerPos p, newx, newy

        p.f ?= 0
        p.ft ?= 0

        p.ft++
        if p.ft > 5
          p.ft = 0
          p.f++

  for b in bullets
    b.age++

    # We'll move the bullet a bit at a time to make sure collision detection is right
    iterations = 3
    s = BSPEED/iterations
    for i in [0...iterations]
      b.x += s * Math.cos b.angle
      b.y += s * Math.sin b.angle

      unless canEnter b.x, b.y + TILE_SIDE/2
        b.die = true
        break

      for id, p of players when b.p isnt p and !b.die
        if within b, p, 30
          b.die = true

          gotHit? id, b

  bullets = (b for b in bullets when b.age < 150 and !b.die)


TAU = Math.PI * 2


TILE_SIDE = 64
dt = 16

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


canEnter = (tx, ty) ->
  return false unless 0 <= tx < map.width and 0 <= ty < map.height
  tileplayer = map.layers.player[tx]?[ty]
  map.layers.scenery[tx][ty] not in ['bot', 'botleft', 'botright']

canEnterXY = (x, y) ->
  ts2 = TILE_SIDE / 2
  #(canEnter (toTile x-ts2), (toTile y-ts2)) and (canEnter (toTile x + ts2), (toTile y + ts2))
  (canEnter (toTile x), (toTile y)) and (canEnter (toTile x), (toTile y + TILE_SIDE))

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

PSPEED = 4
BSPEED = 60

# Shared between server and client
commonUpdate = (gotHit) ->
  for id, p of players
    if p.dx or p.dy
      newx = p.x + p.dx * PSPEED
      newy = p.y + p.dy * PSPEED

      newx = p.x unless canEnterXY newx, p.y
      newy = p.y unless canEnterXY newx, newy

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
    b.x += BSPEED * Math.cos b.angle
    b.y += BSPEED * Math.sin b.angle

    tx = toTile b.x
    ty = toTile b.y + TILE_SIDE/2
    b.die = true unless canEnter tx, ty

    for id, p of players when b.p isnt p
      if within b, p, 30
        b.die = true

        gotHit? id, b

  bullets = (b for b in bullets when b.age < 150 and !b.die)


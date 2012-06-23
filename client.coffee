canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768
TAU = Math.PI * 2

ctx = canvas.getContext '2d'

ws = new WebSocket "ws://#{window.location.host}"
ws.onerror = (e) -> console.log e

dt = 16

myId = null
me = null # The entry in players, for convenience.
players = {}
bullets = []

TILE_SIDE = 64

toTile = (x) -> Math.floor(x / TILE_SIDE)

loadTex = (name) ->
  img = new Image
  img.src = "#{name}.png"
  img

textures = {}
textures[name] = loadTex name for name in ['spritesheet']

frames =
  tile:  [0,0]
  grass: [1,0]
  dirt:  [2,0]
  cobble: [3,0]

  dudedown: [0,2,3]
  dudeleft: [3,2,3]
  dudeup: [6,2,3]
  duderight: [9,2,3]
  dudedead: [9,2,2]

  bot: [0,1]
  top: [1,1]
  botleft: [2,1]
  topleft: [3,1]
  botright: [4,1]
  topright: [5,1]


drawSprite = (name, x, y, a) ->
  f = frames[name]
  throw new Error "missing frame data for #{name}" unless f

  sx = f[0]
  sx += (a % f[2]) if a?
  sy = f[1]

  ctx.drawImage textures.spritesheet, sx * 96, sy * 96, 96, 96, x, y, 96, 96

map = null

username = if window.location.hash
  window.location.hash.substr(1)
else
  prompt "Enter your name"
window.location.hash = username

requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or
                        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

shoot = (p, angle) ->
  bullets.push {x:p.x, y:p.y, angle:angle, age:0, p}

canEnter = (tx, ty) ->
  return false unless 0 <= tx < map.width and 0 <= ty < map.height
  tileplayer = map.layers.player[tx]?[ty]
  map.layers.scenery[tx][ty] not in ['bot', 'botleft', 'botright']

canEnterXY = (x, y) ->
  ts2 = TILE_SIDE / 2
  #(canEnter (toTile x-ts2), (toTile y-ts2)) and (canEnter (toTile x + ts2), (toTile y + ts2))
  (canEnter (toTile x), (toTile y)) and (canEnter (toTile x), (toTile y + TILE_SIDE))

SPEED = 4

setPlayerPos = (p, newx, newy) ->
  console.warn 'Unit not in space' unless p in map.layers.player[toTile p.x]?[toTile p.y]
  map.layers.player[toTile p.x][toTile p.y] = (pl for pl in map.layers.player[toTile p.x][toTile p.y] when pl isnt p)
  p.x = newx
  p.y = newy
  ((map.layers.player[toTile p.x] ||= [])[toTile p.y] ||= []).push p


update = ->
  for id, p of players
    if p.dx or p.dy
      newx = p.x + p.dx * SPEED
      newy = p.y + p.dy * SPEED

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
    b.x -= 7 * Math.cos b.angle
    b.y -= 7 * Math.sin b.angle

    tx = toTile b.x
    ty = toTile b.y + TILE_SIDE/2
    b.die = true unless canEnter tx, ty

  bullets = (b for b in bullets when b.age < 150 and !b.die)

frameCount = 0
lastFrameTime = 0
fpselem = document.getElementById 'fps'


draw = ->
  now = Math.floor(Date.now()/1000)
  if now != lastFrameTime
    fpselem.innerHTML = "FPS: #{frameCount}"
    frameCount = 0
    lastFrameTime = now
  frameCount++

  ctx.fillStyle = 'black'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  if map
    left = me.x - 512
    right = me.x + 512
    top = me.y - 384
    bot = me.y + 384

    ctx.save()
    ctx.translate -(Math.floor(me.x) - 512), -(Math.floor(me.y) - 384)

    psize = 64
    ctx.textAlign = 'center'
    ctx.font = '17px sans-serif'

    for layer in ['ground', 'shadow', 'scenery']
      for y in [toTile(top)..toTile(bot)]
        for x in [toTile(left)..toTile(right)]
          #if layer in ['player', 'shadow', 'scenery'] # Sparse layers
          #  thing = map.layers[layer][[x,y]]
          #else
          thing = map.layers[layer][x]?[y]

          if thing
            drawSprite thing, x * TILE_SIDE - 32, y * TILE_SIDE - 32 if thing

          if layer is 'scenery'
            ps = map.layers.player[x]?[y]
            continue unless ps
            for player in ps
              ctx.fillStyle = 'black'
              ctx.fillText player.name, player.x, player.y - 40
              #ctx.fillStyle = 'red'
              ctx.save()
              ctx.translate player.x, player.y
              #ctx.rotate player.angle
              dir = ['left', 'up', 'right', 'down'][Math.floor((player.angle + TAU/8 + TAU) / TAU * 4) % 4]
              #console.log player.angle, dir, Math.floor(player.angle + TAU / TAU * 4)
              drawSprite "dude#{dir}", -64, -64, player.f
              #ctx.strokeStyle = 'red'
              #ctx.drawImage textures.character, -psize/2, -psize/2
              #ctx.strokeRect -psize/2, -psize/2, psize, psize
              ctx.restore()
 
    ctx.fillStyle = 'black'
    for b in bullets
      ctx.fillRect b.x - 5, b.y - 5, 10, 10

    ctx.restore()


runFrame = ->
  setTimeout runFrame, dt
  update()
  requestAnimationFrame draw

# Sparse layers map from [x,y] -> value
expandSparseLayer = (sparse, width, height) ->
  result = []

  for x in [0...width]
    row = []
    result.push row
    for y in [0...height]
      row[y] = sparse[[x,y]]

  result

ws.onmessage = (msg) ->
  #console.log msg.data
  msg = JSON.parse msg.data

  return unless me or msg.type is 'login'

  switch msg.type
    when 'login'
      map = msg.map
      map.layers.player = []
      map.layers.shadow = expandSparseLayer map.layers.shadow, map.width, map.height
      map.layers.scenery = expandSparseLayer map.layers.scenery, map.width, map.height

      myId = msg.id
      players = msg.players
      for id, p of players
        ((map.layers.player[toTile p.x] ||= [])[toTile p.y] ||= []).push p
      me = players[myId]
    when 'connected'
      p = players[msg.id] = msg.player
      ((map.layers.player[toTile p.x] ||= [])[toTile p.y] ||= []).push p
      console.log 'c', msg.id
    when 'disconnected'
      p = players[msg.id]
      delete players[msg.id]
      map.layers.player[toTile p.x][toTile p.y] = (pl for pl in map.layers.player[toTile p.x][toTile p.y] when pl isnt p)
      console.log 'dc', msg.id
    when 'pos'
      p = players[msg.id]
      #console.log p, msg.x, msg.y
      setPlayerPos p, msg.x, msg.y
      p[k] = msg[k] for k in ['dx', 'dy']
    when 'angle'
      p = players[msg.id]
      p.angle = msg.angle
    when 'attack'
      shoot players[msg.id], msg.angle

send = (msg) -> ws.send JSON.stringify msg

rateLimit = (fn) ->
  queuedMessage = false
  ->
    return if queuedMessage
    queuedMessage = true
    fn()
    setTimeout ->
        queuedMessage = false
      , 50

sendPos = -> send {type:'pos', x:me.x, y:me.y, dx:me.dx, dy:me.dy}

roundSome = (x) -> Math.floor(x * 1000) / 1000
sendAngle = rateLimit -> send {type:'angle', angle:roundSome me.angle}

ws.onopen = ->
  #console.log 'open'
  send {name:username}
  runFrame()

canvas.onmousemove = (e) ->
  return unless me

  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop

  dx = canvas.width/2 - x
  dy = canvas.height/2 - y

  me.angle = Math.atan2 dy, dx

  sendAngle()
  #[self.x, self.y] = [x, y]
  #send {x, y}

canvas.onmousedown = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop

  sendPos()
  angle = me.angle + (Math.random() * 0.2) - 0.1
  send {type:'attack', angle}
  shoot me, angle
  e.preventDefault()

canvas.oncontextmenu = -> false

  #send
  #self.attacking = true
  #send {attack:true, x, y}

keys =
  up: [38, 'W'.charCodeAt(0)]
  left: [37, 'A'.charCodeAt(0)]
  right: [39, 'D'.charCodeAt(0)]
  down: [40, 'S'.charCodeAt(0)]

pressed = {left:0, right:0, up:0, down:0}
updateD = ->
  return unless me
  olddx = me.dx
  olddy = me.dy

  me.dx = pressed.left + pressed.right
  me.dy = pressed.up + pressed.down

  sendPos() if me.dx isnt olddx or me.dy isnt olddy

document.onkeydown = (e) ->
  #console.log e.keyCode
  pressed.left = -1 if e.keyCode in keys.left # Left
  pressed.right = 1 if e.keyCode in keys.right # right
  pressed.up = -1 if e.keyCode in keys.up # up
  pressed.down = 1 if e.keyCode in keys.down
  updateD()

  #if e.keyCode == 32
  #  send {start:true}

document.onkeyup = (e) ->
  pressed.left = 0 if e.keyCode in keys.left
  pressed.right = 0 if e.keyCode in keys.right
  pressed.up = 0 if e.keyCode in keys.up
  pressed.down = 0 if e.keyCode in keys.down

  updateD()

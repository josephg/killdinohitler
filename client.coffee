canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768
TAU = Math.PI * 2

ctx = canvas.getContext '2d'

ws = new WebSocket "ws://#{window.location.host}"
ws.onerror = (e) -> console.log e

dt = 33

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
textures[name] = loadTex name for name in ['sheet', 'character']

frames =
  sand:  [0,0]
  grass: [1,0]
  dirt:  [2,0]
  concrete: [3,0]
  mud:   [4,0]

  ammo:  [0,1]

drawSprite = (name, x, y) ->
  f = frames[name]
  throw new Error "missing frame data for #{name}" unless f
  ctx.drawImage textures.sheet, f[0] * 96, f[1] * 96, 96, 96, x, y, 96, 96

map = null

username = if window.location.hash
  window.location.hash.substr(1)
else
  prompt "Enter your name"
window.location.hash = username

requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or
                        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

shoot = (p) ->
  bullets.push {x:p.x, y:p.y, angle:p.angle, age:0}

update = ->
  for id, p of players
    p.x += p.dx * 5
    p.y += p.dy * 5

  for b in bullets
    b.age++
    b.x -= 10 * Math.cos b.angle
    b.y -= 10 * Math.sin b.angle

  bullets.shift() while bullets.length > 0 and bullets[0].age > 50

draw = ->
  ctx.fillStyle = 'black'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  if map
    left = me.x - 512
    right = me.x + 512
    top = me.y - 384
    bot = me.y + 384

    ctx.save()
    ctx.translate -(Math.floor(me.x) - 512), -(Math.floor(me.y) - 384)

    for y in [toTile(top)..toTile(bot)]
      for x in [toTile(left)..toTile(right)]
        if map.tiles[x]?[y]
          drawSprite map.tiles[x][y], x * TILE_SIDE - 32, y * TILE_SIDE - 32
          #ctx.drawImage textures[map.tiles[x][y]], x * TILE_SIDE, y * TILE_SIDE

    psize = 64
    ctx.textAlign = 'center'
    ctx.font = '15px sans-serif'
    for id, player of players
      ctx.fillStyle = 'white'
      ctx.fillText player.name, player.x, player.y - 33
      #ctx.fillStyle = 'red'
      ctx.save()
      ctx.translate player.x, player.y
      ctx.rotate player.angle
      ctx.drawImage textures.character, -psize/2, -psize/2
      #ctx.fillRect -psize/2, -psize/2, psize, psize
      ctx.restore()
 
    ctx.fillStyle = 'black'
    for b in bullets
      ctx.fillRect b.x - 5, b.y - 5, 10, 10

    ctx.restore()


runFrame = ->
  setTimeout runFrame, dt
  update()
  requestAnimationFrame draw


ws.onmessage = (msg) ->
  msg = JSON.parse msg.data

  return unless me or msg.type is 'login'

  switch msg.type
    when 'login'
      map = msg.map
      myId = msg.id
      players = msg.players
      me = players[myId]
    when 'connected'
      players[msg.id] = msg.player
      console.log 'c', msg.id
    when 'disconnected'
      delete players[msg.id]
      console.log 'dc', msg.id
    when 'pos'
      p = players[msg.id]
      p[k] = msg[k] for k in ['x', 'y', 'dx', 'dy']
    when 'angle'
      p = players[msg.id]
      p.angle = msg.angle
    when 'attack'
      shoot players[msg.id]

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
  console.log 'open'
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
  send {type:'attack'}

  shoot me

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

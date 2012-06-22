canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768

ctx = canvas.getContext '2d'

ws = new WebSocket "ws://#{window.location.host}"
ws.onerror = (e) -> console.log e

dt = 33

myId = null
me = null # The entry in players, for convenience.
players = {}

TILE_SIDE = 64

toTile = (x) -> Math.floor(x / TILE_SIDE)

loadTex = (name) ->
  img = new Image
  img.src = "#{name}.png"
  img

textures = {}
textures[name] = loadTex name for name in ['grass', 'dirt']


map = null

username = if window.location.hash
  window.location.hash.substr(1)
else
  prompt "Enter your name"
window.location.hash = username

requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or
                        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

update = ->
  for id, p of players
    p.x += p.dx * 5
    p.y += p.dy * 5

draw = ->
  ctx.fillStyle = 'black'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  if map
    left = me.x - 512
    right = me.x + 512
    top = me.y - 384
    bot = me.y + 384

    ctx.save()
    ctx.translate -(me.x - 512), -(me.y - 384)

    for y in [toTile(top)..toTile(bot)]
      for x in [toTile(left)..toTile(right)]
        if textures[map.tiles[x]?[y]]
          ctx.drawImage textures[map.tiles[x][y]], x * TILE_SIDE, y * TILE_SIDE

    psize = 32
    ctx.textAlign = 'center'
    ctx.font = '15px sans-serif'
    for id, player of players
      ctx.fillStyle = 'white'
      ctx.fillText player.name, player.x, player.y - 22
      ctx.fillStyle = 'red'
      ctx.save()
      ctx.translate player.x, player.y
      ctx.rotate player.angle
      ctx.fillRect -psize/2, -psize/2, psize, psize
      ctx.restore()

    ctx.restore()


runFrame = ->
  setTimeout runFrame, dt
  update()
  requestAnimationFrame draw


ws.onmessage = (msg) ->
  msg = JSON.parse msg.data
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
      if p
        p[k] = msg[k] for k in ['x', 'y', 'dx', 'dy', 'angle']

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

sendPos = -> send {type:'pos', x:me.x, y:me.y, dx:me.dx, dy:me.dy, angle:me.angle}

sendAngle = rateLimit sendPos

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

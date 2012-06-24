canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768
ctx = canvas.getContext '2d'

ws = new WebSocket "ws://#{window.location.host}"
ws.onerror = (e) -> console.log e

myId = null
me = null # The entry in players, for convenience.

loadTex = (name) ->
  img = new Image
  img.src = "#{name}.png"
  img

textures = {}
textures[name] = loadTex name for name in ['spritesheet']

frames = do ->
  fr = {}

  x = y = 0
  f = (name, num) ->
    num ?= 1
    fr[name] = [x, y, num]
    x += num

  line = ->
    x = 0
    y++

  f 'tile'
  f 'grass'
  f 'dirt'
  f 'cobble'

  line()
  line()

  personthing = (thing) ->
    f "#{thing}down", 3
    f "#{thing}left", 3
    f "#{thing}up", 3
    f "#{thing}right", 3
    f "#{thing}dead" #, 3  dodgy

  personthing 'dude'

  line()

  personthing 'dino'

  line()

  f 'health'
  f 'ammo'
  f 'pistol'
  f 'mg'
  f 'heart'
  f 'shrub'
  f 'grenade'
  f 'rock'
  f 'jacket'
  f 'tree'

  f 'crate'
  f 'barrel'
  f 'knife'

  line()

  f 'top'
  f 'topleft'
  f 'topright'
  f 'left'
  f 'right'

  line()

  f 'rfront'
  f 'rleft'
  f 'rright'
  f 'rdoorright'
  f 'rdoorleft'
  f 'rwindow'
  f 'rflag'

  line()

  f 'pfront'
  f 'pleft'
  f 'pright'
  f 'pdoorright'
  f 'pdoorleft'
  f 'pwindow'
  f 'pflag'

  line() for [1..6]

  personthing 'knife'
  line()
  personthing 'pistol'

  fr

drawSprite = (name, x, y, a) ->
  f = frames[name]
  throw new Error "missing frame data for #{name}" unless f

  sx = f[0]
  sx += (a % f[2]) if a?
  sy = f[1]

  ctx.drawImage textures.spritesheet, sx * 96, sy * 96, 96, 96, x, y, 96, 96

username = if window.location.hash
  window.location.hash.substr(1)
else
  prompt "Enter your name"
window.location.hash = username

requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or
                        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

update = ->
  commonUpdate()

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

    visible = {}
    visible[[toTile(me.x), toTile(me.y)]] = true
    fovsettings =
      shape: fov.SHAPE_CIRCLE
      opaque: (m, x, y) -> !!map.layers.scenery[x]?[y]
      apply: (m, x, y, sx, sy) -> visible[[x,y]] = true

    fovdir = ['east', 'southeast', 'south', 'southwest', 'west', 'northwest', 'north', 'northeast'][Math.floor((me.angle + TAU/8 + TAU) / TAU * 8) % 8]
    fov.beam fovsettings, null, toTile(me.x), toTile(me.y), 6, fovdir, 1.5

    for layer in ['ground', 'shadow', 'scenery']
      for y in [toTile(top)..toTile(bot)]
        for x in [toTile(left)..toTile(right)]
          ctx.globalAlpha = (if visible[[x,y]] then 1 else 0.5)
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
              continue if visible[[x,y]] and player isnt me
              ctx.fillStyle = 'black'
              ctx.fillText player.name, player.x, player.y - 40
              dir = ['right', 'down', 'left', 'up'][Math.floor((player.angle + TAU/8 + TAU) / TAU * 4) % 4]
              sprite = if player.hp then "dude#{dir}" else 'dudedead'
              drawSprite sprite, player.x-64, player.y-64, player.f

              if player.weapon and player.hp
                drawSprite "#{player.weapon}#{dir}", player.x-64, player.y-64, player.f

              #ctx.strokeStyle = 'red'
              #ctx.strokeRect player.x - TILE_SIDE2, player.y, TILE_SIDE, TILE_SIDE2
 
    # Draw bullets
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 5
    #ctx.lineCap = 'round'
    for b in bullets
      [tx, ty] = [toTile(b.x), toTile(b.y)]
      continue unless visible[[tx,ty]]
      ctx.beginPath()
      [x1,y1] = [b.x, b.y]
      [x2,y2] = [b.x + BSPEED * Math.cos(b.angle), b.y + BSPEED * Math.sin b.angle]
      grad = ctx.createLinearGradient x1, y1, x2, y2
      grad.addColorStop 0, 'rgba(0,0,0,0.5)'
      grad.addColorStop 1, 'black'

      ctx.strokeStyle = grad
      ctx.moveTo x1, y1
      ctx.lineTo x2, y2
      #ctx.lineTo b.x + 5, b.y + 5
      #console.log b.x + BSPEED * Math.cos b.angle, b.y + BSPEED * Math.sin b.angle
      ctx.stroke()
      #ctx.fillRect b.x - 5, b.y - 5, 10, 10

    ctx.restore()

    ctx.strokeStyle = 'white'

    # Draw health and ammo
    drawSprite 'heart', 0, 0
    ctx.fillRect 100, 32 + 28, me.hp * 20, 4
    ctx.strokeRect 100 - 1, 32 + 28 - 1, me.hp * 20 + 2, 4 + 2

    drawSprite me.weapon, 0, 60
    for i in [0...me.ammo]
      ctx.fillRect 100 + 12 * i, 60 + 32 + 28, 6, 6
      ctx.strokeRect 100 + 12 * i - 1, 60 + 32 + 28 - 1, 6 + 2, 6 + 2

runFrame = ->
  setTimeout runFrame, dt
  update()
  requestAnimationFrame draw

ws.onmessage = (msg) ->
  #console.log msg.data
  msg = JSON.parse msg.data

  return unless me or msg.type is 'login'

  switch msg.type
    when 'login'
      setMap expandMap msg.gmap

      myId = msg.id
      for id, p of msg.players
        players[id] = p
        addPlayerToGrid p for id, p of players
      me = players[myId]
    when 'connected'
      p = players[msg.id] = msg.player
      addPlayerToGrid p
      console.log 'c', msg.id
    when 'disconnected'
      p = players[msg.id]
      removePlayerFromGrid p
      delete players[msg.id]
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
    when 'gothit'
      {id} = msg
      players[id].hp--

send = (msg) ->
  ws.send JSON.stringify msg

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

  dx = x - canvas.width/2
  dy = y - canvas.height/2

  me.angle = Math.atan2 dy, dx

  sendAngle()
  #[self.x, self.y] = [x, y]
  #send {x, y}

canvas.onmousedown = (e) ->
  x = e.pageX - canvas.offsetLeft
  y = e.pageY - canvas.offsetTop

  e.preventDefault()
  return unless me and me.hp > 0

  if me.weapon is 'knife'

  else if me.ammo > 0
    sendPos()
    angle = me.angle + (Math.random() * 0.05) - 0.025
    send {type:'attack', angle}
    shoot me, angle

    if me.ammo <= 0
      me.weapon = 'knife'

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
  return unless me and me.hp > 0
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

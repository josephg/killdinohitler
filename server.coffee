express = require 'express'
app = express.createServer()

app.use express.static("#{__dirname}/")
port = 8123

# How frequently (in ms) should we advance the world
bytesSent = bytesReceived = 0

WebSocket = require('ws')
WebSocketServer = WebSocket.Server

wss = new WebSocketServer {server: app}

nextId = 1000
getNextId = -> nextId++

# Wheeee!!
eval (require('fs').readFileSync 'common.js').toString 'utf8'

broadcast = (msg, ignored) ->
  s = JSON.stringify msg
  for cc in wss.clients when cc isnt ignored and cc.readyState is WebSocket.OPEN
    bytesSent += s.length
    cc.send s

gotHit = (id, b) ->
  p = players[id]
  if p.hp > 0
    p.hp--
    broadcast {type:'gothit', id}

update = ->
  commonUpdate gotHit
setInterval update, dt


width = 64
height = 64

genMap = ->
  ground = for x in [0...width]
    for y in [0...height]
      'dirt'
  # dirt mud grass cobble tile
  
  # generate roads (all 4 wide)
  roads = Math.floor( 8 + Math.random() * 8 )
  for [0...roads]
    x = 0
    y = 0

    # 0 = south, 1 = east, 2 = north, 3 = west
    direction = if Math.random() < 0.5 then 1 else 0
    
    # start north to south or west to east
    if direction is 0
      x = Math.floor( Math.random() * width )
    else
      y = Math.floor( Math.random() * height )
    
      # create road until it goes off map
    while (0 <= x < width) and (0 <= y < height)
      # thickness for road
      for i in [0..2]
        switch direction
          when 0, 2
            ground[x + i][y] = 'cobble' if ((x + i) < width)
          when 1, 3
            ground[x][y + i] = 'cobble' if ((y + i) < height)
      # continue along road      
      switch direction
        when 0
          ++y
        when 1
          ++x
        when 2
          --y
        when 3
          --x

  shadow = {}
  
  # generate scenery between roads
  scenery = {}
  
  drawBuilding = (x, y, w, h) ->
    scenery[[x,y]] = 'topleft'
    scenery[[x+w-1,y]] = 'topright'
    scenery[[x+w-1,y+h-1]] = 'botRight'
    scenery[[x.y+h-1]] = 'botLeft'
  
  ###
  buildingWidth = 0
  buildingHeight = 0
  buildingX = 0
  buildingY = 0
  # building must have at least a width or height of 2
  for x in [0...width]
    if ground[x][0] != 'cobble'
      if buildingWidth == 0
        buildingX = x
      ++buildingWidth
    for y in [0...height]
      if ground[x][y] != 'cobble'
        if buildingHeight == 0
          buildingY = y
        ++buildingHeight        
      else
        if buildingWidth >= 2 and buildingHeight >= 2
          drawBuilding(buildingX,buildingY,x - buildingX,y - buildingY)
          buildingX = 0
          buildingY = 0
          buildingWidth = 0
          buildingHeight = 0
  ###

  {layers:{ground, shadow, scenery}, width, height}

gmap = genMap()
setMap expandMap gmap

players[getNextId()] =
  name:'herpderp'
  x:100
  y:100
  dx:0
  dy:0
  angle:0
  hp:2
  ammo:8
  weapon:'pistol'


wss.on 'connection', (c) ->
  id = getNextId()

  sendOthers = (msg) ->
    msg.id = id
    broadcast msg, c

  state = 'connecting'
  name = null
  send = (msg) -> c.send JSON.stringify msg
  player = null

  c.on 'message', (msg) ->
    bytesReceived += msg.length

    console.log msg
    try
      msg = JSON.parse msg
    catch e
      console.log 'invalid JSON', e, "'#{msg}'"

    if state is 'connecting'
      name = msg.name
      players[id] = player =
        name:name
        x:Math.random() * 10 * 64
        y:Math.random() * 10 * 64
        dx:0
        dy:0
        angle:0
        hp:2
        ammo:8
        weapon:'pistol'

      addPlayerToGrid player
      throw new Error unless typeof name is 'string'
      state = 'ok'
      send {type:'login', gmap, id, players}
      sendOthers {type:'connected', id, player}
    else
      switch msg.type
        when 'pos'
          setPlayerPos player, msg.x, msg.y
          player[k] = msg[k] for k in ['dx', 'dy']
          sendOthers msg
        when 'angle'
          player.angle = msg.angle
          sendOthers msg
        when 'attack'
          sendOthers msg
          shoot id, msg.angle

      #p = (players[c.name] ?= {alive:false, x:0, y:0})

  c.on 'close', ->
    removePlayerFromGrid player
    delete players[id]
    broadcast {type:'disconnected', id}

interval = 10 # seconds between TX/RX print statements
setInterval ->
    console.log "TX: #{bytesSent/interval}  RX: #{bytesReceived/interval}"
    bytesSent = bytesReceived = 0
  , interval * 1000

app.listen port
console.log "Listening on port #{port}"


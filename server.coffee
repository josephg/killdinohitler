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
  # update dinos
  ### if players?
    for id in [0...DINO_COUNT]
      if players[id]?
        dino = players[id]
        if dino.hp > 0
          if Math.random() < 0.02
            dino.dx *= -1
          if Math.random() < 0.02
            dino.dy *= -1
          setPlayerPos dino, dino.x + dino.dx, dino.y + dino.dy###
  
setInterval update, dt


width = 64
height = 64

genMap = ->  
  ground = for x in [0...width]
    for y in [0...height]
      'dirt'
  # dirt mud grass cobble tile
  
  # generate roads (all 4 wide)
  roads = Math.floor( 10 + Math.random() * 10 )
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
      
      # slight chance road turns
      if Math.random() < 0.1
        left = Math.random() < 0.5
        switch direction
          when 0
            direction = if left then 1 else 3
          when 1
            direction = if left then 2 else 0
          when 2
            direction = if left then 3 else 1
          when 3
            direction = if left then 0 else 2
            
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

  scenery = {}
  
  canBuild = (x,y) ->
    x >= 0 and x < width and y >= 0 and y < height and ground[x][y] != 'cobble' and ground[x][y] != 'grass'
    
  build = (tile,x,y) ->
    ground[x][y] = 'tile'
    scenery[[x,y]] = tile
    
  placeBuilding = (x,y) ->
    if canBuild(x,y)
      #   0
      # 0 ? 0
      #   0
      if canBuild(x-1,y) and canBuild(x+1,y) and canBuild(x,y-1) and canBuild(x,y+1)
        # X 0
        # 0 ? 0
        # X 0
        if canBuild(x-1,y-1) == false and canBuild(x-1,y+1) == false
          if canBuild(x+1,y-1) == false
            build('topleft',x,y)
          else
            build('left',x,y)
        #   0 X
        # 0 ? 0
        #   0 X
        else if canBuild(x+1,y-1) == false and canBuild(x+1,y+1) == false
          build('right',x,y)
        # X 0 X
        # 0 ? 0
        #   0 
        else if canBuild(x-1,y-1) == false or canBuild(x+1,y-1) == false
          if canBuild(x+1,y+1) == false
            build('topright',x,y)
          else
            build('pfront',x,y)
        else
          if canBuild(x+1,y+1) == false
            build('rdleft',x,y)
          else if canBuild(x-1,y+1) == false
            build('rdright',x,y)
          else
            ground[x][y] = 'tile'
      #   0
      # 0 ? 0
      #   X
      else if canBuild(x-1,y) and canBuild(x+1,y) and canBuild(x,y-1) and canBuild(x,y+1) == false
        # X 0
        # 0 ? 0
        #   X
        if canBuild(x-1,y-1) == false
          build('pleft',x,y)
        #   0 X
        # 0 ? 0
        #   X
        else if canBuild(x+1,y-1) == false
          build('pright',x,y)
        else
          build('rfront',x,y)
      #   X
      # 0 ? 0
      #   0
      else if canBuild(x-1,y) and canBuild(x+1,y) and canBuild(x,y-1) == false and canBuild(x,y+1)
        #   X
        # 0 ? 0
        # 0 0 X
        if canBuild(x+1,y+1) == false and canBuild(x-1,y+1)
          build('topright',x,y)
        #   X
        # 0 ? 0
        #   0 X
        if canBuild(x+1,y+1) == false
          build('topright',x,y)
        #   X
        # 0 ? 0
        # X 0 0
        if canBuild(x-1,y+1) == false and canBuild(x-1,y+1)
          build('topleft',x,y)
        #   X
        # 0 ? 0
        #   0
        #   0
        else if canBuild(x,y+2)
          build('pfront',x,y)
        else
          build('top',x,y)
      else if canBuild(x-1,y) and canBuild(x+1,y) == false and canBuild(x,y-1) == false and canBuild(x,y+1)
        build('topright',x,y)
      else if canBuild(x-1,y) == false and canBuild(x+1,y) and canBuild(x,y-1) == false and canBuild(x,y+1)
        build('topleft',x,y)
      else if canBuild(x-1,y) and canBuild(x+1,y) == false and canBuild(x,y-1) and canBuild(x,y+1) == false
        build('rright',x,y)
      else if canBuild(x-1,y) == false and canBuild(x+1,y) and canBuild(x,y-1) and canBuild(x,y+1) == false
        build('rleft',x,y)
      else if canBuild(x-1,y) == false and canBuild(x+1,y) and canBuild(x,y-1) and canBuild(x,y+1)
        if canBuild(x+1,y-1) == false
          build('topleft',x,y)
        else if canBuild(x+1,y+1) == false
          build('rleft',x,y)
        else
          build('left',x,y)
      #   0 
      # 0 ? X
      #   0
      else if canBuild(x-1,y) and canBuild(x+1,y) == false and canBuild(x,y-1) and canBuild(x,y+1)
        if canBuild(x+1,y-1) == false and canBuild(x-1,y-1) == false
          build('topright',x,y)
        else if canBuild(x-1,y+1) == false
          build('rright',x,y)
        else
          build('right',x,y)
  
  for x in [0...width]
    for y in [0...height]
      placeBuilding(x,y)          
  
  for x in [0...width]
    for y in [0...height]
      if ground[x][y] == 'cobble' and Math.random() < 0.02
        ground[x][y] = 'dirt'
      if ground[x][y] == 'dirt'
        ground[x][y] = 'grass'
        if Math.random() < 0.25
          scenery[[x,y]] = 'shrub'
    
  for x in [1...width]
    for y in [0...height-1]
      if scenery[[x-1,y]]? and scenery[[x,y]]? and scenery[[x+1,y]]? and scenery[[x+2,y]]? and scenery[[x,y-1]]? == false and scenery[[x+1,y-1]]? == false
        if scenery[[x-1,y]] != 'rdooropen' and scenery[[x,y]] == 'rfront' and scenery[[x+1,y]] == 'rfront' and scenery[[x+2,y]] == 'rfront' and Math.random() < 0.1
          scenery[[x,y]] = 'ldooropen'
          scenery[[x+1,y]] = 'rdooropen'
        else scenery[[x-1,y]] != 'rdooropen' and if scenery[[x,y]] == 'pfront' and scenery[[x+1,y]] == 'pfront'and scenery[[x+2,y]] == 'pfront'  and Math.random() < 0.1
          scenery[[x,y]] = 'ldooropen'
          scenery[[x+1,y]] = 'rdooropen'
    
  y = 0
  while y < height
    x = 0
    while x < width
      # window
      if scenery[[x,y]]? and scenery[[x,y-1]]? == false
        if Math.random() < 0.5
          if scenery[[x,y]] == 'rfront'
            scenery[[x,y]] = if Math.random() < 0.6 then 'rwindow' else if Math.random() < 0.5 then 'rflag1' else 'rflag2'
            ++x
          else if scenery[[x,y]] == 'pfront'
            scenery[[x,y]] = if Math.random() < 0.6 then 'pwindow' else if Math.random() < 0.5 then 'pflag1' else 'pflag2'
            ++x
      ++x
    ++y
    
  cobbleCount = 0
  for x in [0...width]
    for y in [0...height]
      if ground[x][y] == 'cobble'
        ++cobbleCount

  {layers:{ground, shadow, scenery}, width, height, cobbleCount}

gmap = genMap()
setMap expandMap gmap

spawnLoc = ->
  ground = gmap.layers.ground
  c = 1 + Math.floor( Math.random() * (gmap.cobbleCount - 1) )
  spawnX = 0
  spawnY = 0  
  for x in [0...width]
    for y in [0...height]
      if ground[x][y] == 'cobble'
        if --c == 0
          spawnX = x
          spawnY = y
  [spawnX * TILE_SIDE + TILE_SIDE2, spawnY * TILE_SIDE + TILE_SIDE2]

players[getNextId()] =
  name:'herpderp'
  type:'dude'
  x:100
  y:100
  dx:0
  dy:0
  angle:0
  hp:2
  ammo:8
  weapon:'pistol'

dinoSpawnLoc = ->
  spawnX = Math.floor( Math.random() * width )
  spawnY = Math.floor( Math.random() * height )
  scenery = gmap.layers.scenery
  while scenery[[spawnX,spawnY]]? == true
    spawnX = Math.floor( Math.random() * width )
    spawnY = Math.floor( Math.random() * height )
  [spawnX * TILE_SIDE + TILE_SIDE2, spawnY * TILE_SIDE + TILE_SIDE2]

do ->
  for id in [0...DINO_COUNT]
    [x,y] = dinoSpawnLoc()
    dirx = Math.random()
    diry = Math.random()
    d = players[id] =
      name:'DinoNazi'
      type:'dino'
      x:x
      y:y
      dx: if dirx < 0.25 then -1 else if dirx < 0.75 then 0 else 1
      dy: if diry < 0.25 then -1 else if diry < 0.75 then 0 else 1
      angle:0
      hp:2
      ammo:8
      weapon:'pistol'
    addPlayerToGrid d

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

    try
      if state is 'connecting'
        name = msg.name
        [x,y] = spawnLoc()
        console.log x
        console.log y
        players[id] = player =
          name:name
          type: if Math.random() < 0.5 then 'dude' else 'man'
          x:x
          y:y
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

    catch e
      console.log "Error: #{e.message} #{e.stack}"
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


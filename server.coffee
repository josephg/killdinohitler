#http = require 'http'

express = require 'express'
app = express.createServer()

app.use express.static("#{__dirname}/")
port = 8123

# How frequently (in ms) should we advance the world
dt = 16
snapshotDelay = 5
bytesSent = bytesReceived = 0

WebSocket = require('ws')
WebSocketServer = WebSocket.Server

wss = new WebSocketServer {server: app}

nextId = 1000
getNextId = -> nextId++
players = {}
bullets = []

dist2 = (a, b) ->
  dx = a.x - b.x
  dy = a.y - b.y
  dx * dx + dy * dy

within = (a, b, dist) ->
  dist2(a, b) < dist * dist

shoot = (id) ->
  p = players[id]
  bullets.push {x:p.x, y:p.y, angle:p.angle, age:0, id}

update = ->
  for b in bullets
    b.age++
    b.x -= 10 * Math.cos b.angle
    b.y -= 10 * Math.sin b.angle

    # Urgh id is a string.
    for id, p of players when id isnt "#{b.id}"
      if within p, b, 35
        # Hit.
        console.log 'hit'



  bullets.shift() while bullets.length > 0 and bullets[0].age > 50

setInterval update, dt

width = 64
height = 64
minRoads = 10
maxRoads = 20
genMap = ->
  ground = for x in [0...width]
    for y in [0...height]
      'dirt'
      
  roads = Math.floor( minRoads + Math.random() * (maxRoads - minRoads) )
  
  for [0...roads]
    x = 0
    y = 0
    r = Math.random()
    if r < 0.5
      x = Math.floor( Math.random() * width )
      for y in [0...height]
        ground[x][y] = 'cobble'
    else
      y = Math.floor( Math.random() * height )
      for x in [0...width]
        ground[x][y] = 'cobble'
    #  r = Math.random()
     # if r < 0.2
     #   'tile'
    #  else if r < 0.4
     #   'grass'
    #  else if r < 0.6
     #   'dirt'
     # else
     #   'cobble'
      # else
      #  'mud'

#  for x in [0...10]
 #   for y in [0...10]
#      ground[x][y] = 'tile'

 # for x in [10...20]
 #   for y in [0...10]
 #     ground[x][y] = 'grass'

#  for x in [20...30]
#    for y in [0...10]
 #     ground[x][y] = 'dirt'

 # for x in [0...10]
 #   for y in [10...20]
 #     ground[x][y] = 'cobble'

  shadow = {}
  scenery = {}

 # scenery[[4,9]] = 'topleft'
 # scenery[[4,10]] = 'botleft'
#  for x in [5..15]
 #   scenery[[x,9]] = 'top'
 #   scenery[[x,10]] = 'bot'
 # scenery[[16,9]] = 'topright'
#  scenery[[16,10]] = 'botright'

  {layers:{ground, shadow, scenery}, width, height}


map = genMap()

broadcast = (msg, ignored) ->
  s = JSON.stringify msg
  for cc in wss.clients when cc isnt ignored and cc.readyState is WebSocket.OPEN
    bytesSent += s.length
    cc.send s

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
    try
      msg = JSON.parse msg

      if state is 'connecting'
        name = msg.name
        players[id] = player = {name, x:Math.random() * 10 * 64, y:Math.random() * 10 * 64, dx:0, dy:0, angle:0}
        throw new Error unless typeof name is 'string'
        state = 'ok'
        send {type:'login', map, id, players}
        sendOthers {type:'connected', id, player}
      else
        switch msg.type
          when 'pos'
            player[k] = msg[k] for k in ['x', 'y', 'dx', 'dy']
            sendOthers msg
          when 'angle'
            player.angle = msg.angle
            sendOthers msg
          when 'attack'
            sendOthers msg
            shoot id
            
      console.log msg

      #p = (players[c.name] ?= {alive:false, x:0, y:0})
    catch e
      console.log 'invalid JSON', e, msg

  c.on 'close', ->
    delete players[id]
    broadcast {type:'disconnected', id}

interval = 10 # seconds between TX/RX print statements
setInterval ->
    console.log "TX: #{bytesSent/interval}  RX: #{bytesReceived/interval}"
    bytesSent = bytesReceived = 0
  , interval * 1000

app.listen port
console.log "Listening on port #{port}"


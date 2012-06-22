#http = require 'http'

express = require 'express'
app = express.createServer()

app.use express.static("#{__dirname}/")
port = 8123

# How frequently (in ms) should we advance the world
dt = 33
snapshotDelay = 5
bytesSent = bytesReceived = 0

WebSocket = require('ws')
WebSocketServer = WebSocket.Server

wss = new WebSocketServer {server: app}

setInterval ->
  b.update() if b?
, dt

nextId = 1000
getNextId = -> nextId++
players = {}

width = 64
height = 64
genMap = ->
  tiles = for x in [0...width]
    for y in [0...height]
      if Math.random() < 0.9 then 'grass' else 'dirt'

  {tiles, width, height}


map = genMap()

broadcast = (msg, ignored) ->
  s = JSON.stringify msg
  for cc in wss.clients when cc isnt ignored and cc.readyState is WebSocket.OPEN
    bytesSent += s.length
    cc.send s

wss.on 'connection', (c) ->
  sendOthers = (msg) -> broadcast msg, c

  state = 'connecting'
  name = null
  id = getNextId()
  send = (msg) -> c.send JSON.stringify msg
  player = null

  c.on 'message', (msg) ->
    bytesReceived += msg.length
    try
      msg = JSON.parse msg

      if state is 'connecting'
        name = msg.name
        players[id] = player = {name, x:100, y:100, dx:0, dy:0, angle:0}
        throw new Error unless typeof name is 'string'
        state = 'ok'
        send {type:'login', map, id, players}
        sendOthers {type:'connected', id, player}
      else
        switch msg.type
          when 'pos'
            player[k] = msg[k] for k in ['x', 'y', 'dx', 'dy', 'angle']
            msg.id = id
            sendOthers msg
            

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


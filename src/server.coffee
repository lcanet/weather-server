express = require 'express'
Backend = require('./backend').Backend

backend = new Backend()

###
backend.withCollection 'testcol', (err, col) ->
  if err
    console.log err
  else
    col.find().toArray (err, res) ->
      console.log 'Find ok'
      console.dir res

###

# run server
app = express()

app.get '/', (req,res) ->
  res.send 'Hello'


port = process.env.WEATHER_PORT or 18580

app.listen port, ->
  console.log "Server launched on #{port}"
express = require 'express'
winston = require 'winston'
_ = require 'lodash'
Backend = require('./backend').Backend
Poller = require('./poller').Poller

# DB Backend
backend = new Backend()

# Poller
poller = new Poller(backend)
poller.startPoller()

app = express()

# define routes

sendError = (res, message) ->
  if _.isObject(message) and message.message
    message = message.message
  winston.error message
  res.status(500).send(message || 'Sorry, we have an error')

app.get '/', (req,res) ->
  res.send 'Weather Server'

app.get '/station/:code', (req,res) ->
  backend.withConnection (err, db) ->
    if err
      sendError res, err
    else
      db.collection('stations').findOne {code: req.params.code}, (err, doc) ->
        if err
          sendError res, err
        else if doc
          res.json(doc)
        else
          res.status(404).send('Station not found')

app.get '/station/:code/history', (req,res) ->
  backend.withConnection (err, db) ->
    if err
      winston.error 'Cannot connect to mongo: ' + err
      sendError res
    else
      limit = parseInt(req.params.limit) || 100
      db.collection('history').find({icao: req.params.code}, { sort: [['date', -1]], limit: limit}).toArray (err, doc) ->
        if err
          sendError res, err
        else
          res.json(doc)




# run server

port = process.env.WEATHER_PORT or 18580

app.listen port, (err) ->
  if err
    winston.error 'Cannot bind on port ' + port
  else
    winston.log 'info', 'Server launched on port %d', port
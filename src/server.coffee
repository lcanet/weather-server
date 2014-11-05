express = require 'express'
winston = require 'winston'
_ = require 'lodash'
logEntries = require 'winston-logentries'
config = require '../config.json'
Backend = require('./backend').Backend
Poller = require('./poller').Poller
transformers = require './transformers'
responseTime = require './responseTime'
metar = require './metar'
DataExtractor = require('./dataExtractor').DataExtractor

# Logging
winston.add(winston.transports.DailyRotateFile, { filename: 'weather-server.log', level: 'debug' });
if config.logEntriesToken
  winston.add(winston.transports.Logentries, { token: config.logEntriesToken, level: 'debug' });


# DB Backend
backend = new Backend()

# Poller
poller = new Poller(backend)
poller.startPoller()

app = express()
app.use responseTime()

# define routes

sendError = (res, message) ->
  if _.isObject(message) and message.message
    message = message.message
  winston.error message
  res.status(500).send(message || 'Sorry, we have an error')

sendInvalid = (res, message) ->
  res.status(400).send message

app.use '/web', express.static('web')

app.get '/', (req,res) ->
  res.send 'Weather Server'

### ---------------------------------------------------
Weather at a location

###

app.get '/weather', (req,res) ->
  lat = parseFloat(req.query.lat)
  lon = parseFloat(req.query.lon)

  if isNaN(lat) or isNaN(lon)
    sendInvalid res, 'invalid parameters: need lat or lon'
  else
    geoJsonpt = type:'Point', coordinates: [lon, lat]
    query = { geoNear: 'stations', near: geoJsonpt, spherical:true, query: { last: {$exists: 1}}}
    if req.query.distance
      query.maxDistance = parseFloat(req.query.distance) * 1000
      query.limit = parseInt(req.query.limit) or 100
    else
      query.limit = 1
    winston.log 'debug', 'Weather request at ' + lat + ' - ' + lon

    backend.withConnection (err,db) ->
      if err
        sendError res, err
      else
        db.command query, (err, cb) ->
          if err
            sendError res, err
          else
            if query.limit is 1
              res.jsonp(transformers.transformGeoNear(cb.results[0], req.query.format))
            else
              res.jsonp(transformers.transformGeoNears(cb.results, req.query.format))

          db.close()

### ---------------------------------------------------
Weather at one station

###


app.get '/station/:code', (req,res) ->
  winston.log 'debug', 'Request station %s', req.params.code

  backend.withConnection (err, db) ->
    if err
      sendError res, err
    else
      db.collection('stations').findOne {code: req.params.code}, (err, doc) ->
        if err
          sendError res, err
        else if doc
          res.jsonp(transformers.transform(doc, req.query.format))
        else
          res.status(404).send('Station not found')
        db.close()

### ---------------------------------------------------
  History of one statin

###


app.get '/station/:code/history', (req,res) ->
  backend.withConnection (err, db) ->
    if err
      winston.error 'Cannot connect to mongo: ' + err
      sendError res
    else
      limit = parseInt(req.params.limit) || 100
      db.collection('history').find({icao: req.params.code}, { sort: [['date', -1]], limit: limit}).toArray (err, docs) ->
        if err
          sendError res, err
        else
          res.jsonp(transformers.transformHistory(docs, req.query.format))
        db.close()


### ---------------------------------------------------
Extract data to CSV, according to one measure

###

new DataExtractor(backend).registerRoutes(app)


### ---------------------------------------------------
  Other administratives endpoints

###


app.get '/poll', (req,res) ->
  winston.log 'info', 'Polling forced'
  res.send 'OK'
  poller.pollDir (err, res) ->
    if err
      winston.error 'Error while polling :' + err

app.get '/parse', (req,res) ->
  reqMetar = req.query.metar
  decoded = metar.decode reqMetar
  station = code: metar.icao, last: decoded, tz: 'GMT'
  res.jsonp transformers.transform(station, req.query.format)


# run server

port = process.env.WEATHER_PORT or 18580

app.listen port, (err) ->
  if err
    winston.error 'Cannot bind on port ' + port
  else
    winston.log 'info', 'Server launched on port %d', port
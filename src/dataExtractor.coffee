winston = require 'winston'
get = require('getobject').get
_ = require 'lodash'

# TODO: chunked output/streaming


class DataExtractor
  constructor: (@backend) ->

  measureOf: (obj, measure) ->
    if obj
      get obj, measure
    else
      null

  ###
  Proceed to extraction
  ###
  extract: (params, callback) ->
    @backend.withConnection (err, db) =>
      return callback err if err

      lines = []
      if params.filter is 'space'
        query = $and: [ {lat: { $gte: params.extent[0] }},
          { lat: { $lt: params.extent[2]}},
          { lon: { $gte: params.extent[1]}},
          { lon: { $lt: params.extent[3]}}  ]
        db.collection('stations').find(query).each (err, doc) =>
          return callback err if err
          if doc is null
            callback null, lines
            db.close()
          else
            measureVal = @measureOfDoc doc.last, params.measure
            if measureVal isnt null
              line = lat: doc.lat, lon: doc.lon, code: doc.code, city: doc.city, measure: measureVal
              lines.push line

      else if params.filter is 'time'
        db.collection('stations').findOne {code: params.code}, (err, station) =>
          return callback err if err

          db.collection('history').find({icao: params.code}).each (err, doc) =>
            return callback err if err
            if doc is null
              callback null, lines
              db.close()
            else
              measureVal = @measureOf doc, params.measure
              if measureVal isnt null
                line = lat: station.lat, lon: station.lon, code: station.code, city: station.city, date: doc.date.getTime(), measure: measureVal
                lines.push line



  ###
  Build parame
  ###
  buildParams: (req) ->
    params = {}
    params.filter = req.query.filter || 'space'
    params.extent = _.map req.query.extent?.split(','), parseFloat
    params.code = req.query.code
    params.measure = req.query.measure
    params.format = req.params.format
    params

  validateParams: (params) ->
    message = null
    if params.filter is 'space'
      message = 'Invalid extent' if params.extent.length isnt 4
    else if params.filter is 'time'
      message = 'Need ICAO code' if !params.code

    message = 'Missing measure' if !params.measure
    message = 'Invalid output. Only CSV is supported' if params.format isnt 'csv'
    message

  toOutput: (format, lines) ->
    if format is 'csv'
      @toCSV lines

  toCSV: (lines) ->
    (_.map lines, (line) -> [line.lat, line.lon, line.code, line.city, line.date, line.measure].join(',')).join '\r\n'

  outputMimeType: (format) ->
    'text/csv' if format is 'csv'

  ###
  Register express routes
  ###
  registerRoutes: (app) ->
    app.get '/test', (req, res) -> res.send('Ici ' + num) for num in [0..100]

    app.get '/data/:format', (req, res) =>

      params = @buildParams req
      paramsValidation = @validateParams params
      if paramsValidation isnt null
        res.status(400).send paramsValidation
      else
        @extract params, (err, results) =>
          if err
            message = err.message || err
            winston.log 'error', 'Error exporting: %s', message
            res.status(500).send 'Sorry, we have a problem'
          else
            res.set 'Content-Type', @outputMimeType(params.format)
            res.send @toOutput(params.format, results)



exports.DataExtractor = DataExtractor
winston = require 'winston'
get = require('getobject').get
_ = require 'lodash'

# TODO: chunked/streaming


class DataExtractor
  constructor: (@backend) ->

  measureOfDoc: (doc, measure) ->
    if doc.last
      get doc.last, measure
    else
      null

  ###
  Proceed to extraction
  ###
  extract: (params, callback) ->
    @backend.withConnection (err, db) =>
      if err
        callback err

      query = $and: [ {lat: { $gte: params.extent[0] }},
        { lat: { $lt: params.extent[2]}},
        { lon: { $gte: params.extent[1]}},
        { lon: { $lt: params.extent[3]}}  ]

      lines = []

      db.collection('stations').find(query).each (err, doc) =>
        if err
          callback err
        else if doc is null
          callback null, lines
          db.close()
        else
          measureVal = @measureOfDoc doc, params.measure
          if measureVal isnt null
            line = lat: doc.lat, lon: doc.lon, code: doc.code, measure: measureVal
            lines.push line

  ###
  Build parame
  ###
  buildParams: (req) ->
    params = {}
    params.extent = _.map req.query.extent?.split(','), parseFloat
    params.measure = req.query.measure
    params.format = req.params.format
    params

  validateParams: (params) ->
    message = null
    message = 'Invalid extent' if params.extent.length isnt 4
    message = 'Missing measure' if !params.measure
    message = 'Invalid output. Only CSV is supported' if params.format isnt 'csv'
    message

  toOutput: (format, lines) ->
    if format is 'csv'
      @toCSV lines

  toCSV: (lines) ->
    (_.map lines, (line) -> [line.lat, line.lon, line.code, line.measure].join(',')).join '\r\n'

  ###
  Register express routes
  ###
  registerRoutes: (app) ->
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
            res.set 'Content-Type', 'text/csv'
            res.send @toOutput(req.params.format, results)



exports.DataExtractor = DataExtractor
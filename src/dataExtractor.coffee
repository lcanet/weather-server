winston = require 'winston'
get = require('getobject').get
_ = require 'lodash'
Readable = require('stream').Readable
util =require 'util'


class CSVDataProducer extends Readable
  constructor: (@backend, @params, opt) ->
    Readable.call this, opt
    @cursor = null
    @nbLines = 0

  _read: ->
    if @cursor is null
      @initCursors()
    else
      @fetchNextRow()

  fetchNextRow: () ->
    @cursor.nextObject (err, doc) =>
      return @endError(err) if err
      if doc is null
        @push null
        @db.close()
        winston.log 'info', 'Done extraction of %d lines', @nbLines
      else
        @handleRow doc

  measureOf: (obj, measure) ->
    if obj
      get obj, measure
    else
      null

  endError: (err) ->
    winston.error 'Error while feeding data ' + (err.message || err)
    @emit 'error', err

  initCursors: ->
    @backend.withConnection (err, db) =>
      return @endError(err) if err

      @db = db

      if @params.filter is 'space'
        query = $and: [ {lat: { $gte: @params.extent[0] }},
          { lat: { $lt: @params.extent[2]}},
          { lon: { $gte: @params.extent[1]}},
          { lon: { $lt: @params.extent[3]}}  ]
        @cursor = db.collection('stations').find(query)
        @push 'lat,lon,code,city,measure\r\n'

      else if @params.filter is 'time'
        db.collection('stations').findOne {code: @params.code}, (err, doc) =>
          return @endError(err) if err
          @currentStation = doc
          @cursor = db.collection('history').find({icao: @params.code})
          @cursor.sort [['date', 1]]
          @push 'lat,lon,code,city,time,measure\r\n'

  escape: (x) ->
    if !_.isString(x) or x.indexOf(',') is -1 then x else '"' + x + '"'

  pushRow: (values...) ->
    @push (_.map values, @escape).join(',') + '\r\n'

  handleRow: (doc) ->
    if @params.filter is 'space'
      measureVal = @measureOf doc.last, @params.measure
      if measureVal isnt null
        @pushRow doc.lat, doc.lon, doc.code, doc.city, measureVal
        @nbLines++
      else
        @fetchNextRow()
    else if @params.filter is 'time'
      measureVal = @measureOf doc, @params.measure
      if measureVal isnt null
        @pushRow @currentStation.lat, @currentStation.lon, @currentStation.code, @currentStation.city, doc.date.getTime(), measureVal
        @nbLines++
      else
        @fetchNextRow()




class DataExtractor
  constructor: (@backend) ->

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
        producer = new CSVDataProducer(@backend, params)
        winston.log 'info', 'Began extraction parameters: ' + util.inspect(params).replace(/[\r\n]/g, ' ')
        producer.on 'error', (err) ->
          winston.log 'info', 'Data production error, closing request'
          res.end()

        producer.pipe(res)



exports.DataExtractor = DataExtractor
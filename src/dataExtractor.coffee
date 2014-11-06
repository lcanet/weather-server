winston = require 'winston'
get = require('getobject').get
_ = require 'lodash'
Readable = require('stream').Readable
util =require 'util'


class CSVDataProducer extends Readable
  constructor: (@backend, @params, opt) ->
    Readable.call this, opt
    @cursor = null

  _read: ->
    if @cursor is null
      @initCursors()
    else
      @cursor.nextObject (err, doc) =>
        return @endError(err) if err
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

  handleRow: (doc) ->
    if doc is null
      @push null
      @db.close()
    else
      if @params.filter is 'space'
        measureVal = @measureOf doc.last, @params.measure
        if measureVal isnt null
          @push [doc.lat, doc.lon, doc.code, doc.city, measureVal].join(',') + '\r\n'
      else if @params.filter is 'time'
        measureVal = @measureOf doc, @params.measure
        if measureVal isnt null
          @push [@currentStation.lat, @currentStation.lon, @currentStation.code, @currentStation.city, doc.date.getTime(), measureVal].join(',') + '\r\n'




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
        producer.on 'error', (err) ->
          winston.log 'info', 'Data production error, closing request'
          res.end()

        producer.pipe(res)



exports.DataExtractor = DataExtractor
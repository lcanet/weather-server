winston = require 'winston'
Canvas = require 'canvas'
mathjs = require 'mathjs'
_ = require 'lodash'
moment = require 'moment'
color = require 'color'
gradient = require 'tinygradient'
MeasureGrid = require('./grid').MeasureGrid
Stopwatch = require('node-stopwatch').Stopwatch;
Projection = require('./projection').Projection

class TileMeasureExtractor
  constructor: (@minValue, @maxValue, colors...) ->
    @gradient = gradient(colors).rgb(256).reverse()
    @a = 256 / (@maxValue - @minValue)
    @b = -@minValue * @a

  getValueProperty: () ->
    null

  getValue: (stationRecord) ->
    NaN

  getDefaultAlpha: ->
    0.5

  getColor: (val) ->
    val = @minValue if val < @minValue
    val = @maxValue if val > @maxValue
    norm = Math.floor(@a * val + @b)
    if norm > @gradient.length - 1
      norm = @gradient.length - 1
    @gradient[norm]


class TemperatureMeasureExtractor extends TileMeasureExtractor
  constructor: ->
    super -20, 50, '#ff0000', '#ff7f00', '#ffff00', '#00ff00', '#00ffff', '#0000ff', '#8b00ff'

  getValueProperty: () ->
    'last.temperature'

  getValue: (stationRecord) ->
    stationRecord.last.temperature

class PressureMeasureExtractor extends TileMeasureExtractor
  constructor: ->
    super 980, 1050, '#f0f9e8', '#ccebc5', '#a8ddb5', '#7bccc4', '#4eb3d3', '#2b8cbe', '#2b8cbe'

  getDefaultAlpha: ->
    0.8

  getValueProperty: () ->
    'last.altimeter'

  getValue: (stationRecord) ->
    value = stationRecord.last.altimeter
    if value is null or value < 500 or value > 1500 then NaN else value


class WindMeasureExtractor extends TileMeasureExtractor
  constructor: ->
    super 5, 25, '#b10026', '#fd8d3c','#ffffb2'

  getValueProperty: () ->
    'last.wind.speed'

  getValue: (stationRecord) ->
    if stationRecord.last.wind then stationRecord.last.wind.speed else NaN


class MapTileProducer
  constructor: (@backend) ->
    @projection = new Projection()

  DEFAULT_GRID_SIZE: 32
  MAX_DATA_AGE: 6   # In hours

  createGrid: (docs, measureExtractor, gridSize, tile) ->
    grid = new MeasureGrid(gridSize, tile)
    tileOriginPix = @projection.latLonToPoint(@projection.tileToLatLon(tile), tile.z)

    # extract values
    gridWidth = grid.gridWidth()

    # Create sample in grid coordinates
    values = _.map docs, (doc) =>
      value = if doc.last then measureExtractor.getValue(doc) else NaN
      docPix = @projection.latLonToPointRelative doc, tileOriginPix, tile.z
      docGridX = Math.floor(docPix.x / gridWidth)
      docGridY = Math.floor(docPix.y / gridWidth)
      { x: docGridX, y: docGridY, value: value }

    # remove bad samples
    values = _.filter values, (v) -> !isNaN(v.value)

    stopWatch = Stopwatch.create()
    stopWatch.start();
    grid.fillFromValues values, 5
    stopWatch.stop();
    winston.log 'info', 'Interpolation on ' + grid.gridSize() + ' cell points and ' + values.length + ' samples took ' + stopWatch.elapsedMilliseconds + ' ms.'
    grid


  drawPoint: (ctx, tileOriginPix, zoom, doc) ->
    docPix = @projection.latLonToPointRelative {lat: doc.lat, lon: doc.lon}, tileOriginPix, zoom
    ctx.fillStyle = "#FF0000"
    ctx.fillRect docPix.x-3, docPix.y-3, 6, 6

  drawGrid: (ctx, measureExtractor, grid, alpha) ->
    gridWidth = grid.gridWidth()
    n = grid.gridSize()

    # fill canvas
    for i in [0...n]
      for j in [0...n]
        val = grid.valueAt i, j
        if !isNaN(val)
          color = measureExtractor.getColor val
          color.setAlpha alpha
          colorStr = color.toRgbString()
          ctx.fillStyle = colorStr
          ctx.fillRect i*gridWidth, j*gridWidth, gridWidth, gridWidth


  applyWatermark: (ctx) ->
    ctx.translate 128, 128
    ctx.rotate Math.PI / 4
    ctx.font = 'italic 12px Verdana'
    ctx.fillStyle = '#D0D0D080'
    ctx.textAlign = 'center'
    ctx.fillText 'weather-api.lc6.net', 0, 0

  produceMap: (tile, measureExtractor, gridSize, drawStations, alpha, callback)  ->

    # corner of tile in lat/lon
    tileMinLatLon = @projection.tileToLatLon tile
    tileMaxLatLon = @projection.tileToLatLon { x: tile.x+1, y: tile.y+1, z: tile.z }
    tileOriginPix = @projection.latLonToPoint tileMinLatLon, tile.z

    bufferLon = 20 # in degrees
    bufferLat = 5 # in degrees

    # prepare query
    query = $and: [ {lat: { $gte: tileMaxLatLon.lat - bufferLat }},
      { lat: { $lt: tileMinLatLon.lat + bufferLat }},
      { lon: { $gte: tileMinLatLon.lon - bufferLon }},
      { lon: { $lt: tileMaxLatLon.lon + bufferLon }},
      { lastUpdate: { $gte: moment().subtract(@MAX_DATA_AGE, 'hours').toDate() }}
    ]

    fields = ['lastUpdate', 'lat', 'lon']
    fields.push measureExtractor.getValueProperty()

    canvas = new Canvas 256, 256
    ctx = canvas.getContext '2d'

    @backend.withConnection (err, db) =>
      return callback err if err
      db.collection('stations').find(query, _.flatten(fields)).toArray (err, docs) =>
        db.close()
        return callback err if err

        # draw grid
        grid = @createGrid docs, measureExtractor, gridSize, tile

        @drawGrid ctx, measureExtractor, grid, alpha

        # draw station locations
        @drawPoint(ctx, tileOriginPix, tile.z, doc) for doc in docs if drawStations

        # finally apply watermarks
        # @applyWatermark ctx

        callback null, canvas.toBuffer()

  sendError: (res, err) ->
    winston.log 'error', 'Cannot produce tile' + (err.message || err)
    res.status(500).send('oops, an error occured')

  buildMeasure: (measure) ->
    if measure is 'temperature'
      return new TemperatureMeasureExtractor()
    else if measure is 'pressure'
      return new PressureMeasureExtractor()
    else if measure is 'wind'
      return new WindMeasureExtractor()
    else
      return null

  registerRoutes: (app) ->
    app.get '/map/:measure/:z/:x/:y.png', (req, res) =>

      measureExtractor = @buildMeasure req.params.measure
      if measureExtractor is null
        return res.status(400).send('Invalid measure')

      tile =
        x:  parseInt(req.params.x),
        y:  parseInt(req.params.y),
        z:  parseInt(req.params.z)

      gridSize = if req.query.grid then parseInt(req.query.grid) else @DEFAULT_GRID_SIZE
      stations = !!req.query.stations
      alpha = if req.query.alpha then parseFloat(req.query.alpha) else measureExtractor.getDefaultAlpha()

      @produceMap tile, measureExtractor, gridSize, stations, alpha, (err, pngBuf) =>
        return @sendError(res, err) if err

        res.set 'Content-Type', 'image/png'
        res.send pngBuf



exports.MapTileProducer = MapTileProducer
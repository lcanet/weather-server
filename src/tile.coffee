winston = require 'winston'
Canvas = require 'canvas'
mathjs = require 'mathjs'
_ = require 'lodash'
color = require 'color'
gradient = require 'tinygradient'
MeasureGrid = require('./grid').MeasureGrid

class ProjectionUtils
  constructor: ->

  MAX_LATITUDE: 85.0511287798,
  MAP_TRANSFORMATION: [ 0.5 / Math.PI,  0.5,  -0.5 / Math.PI, 0.5]

  tileToLatLon: (tile) ->
    n = mathjs.pow(2, tile.z)
    lonDeg = tile.x / n * 360.0 - 180.0
    latRad = mathjs.atan( mathjs.sinh( Math.PI * ( 1 - 2 * tile.y / n)))
    latDeg = latRad * 180.0 / Math.PI
    return {lat: latDeg, lon: lonDeg }

  lonLatToTile: (pt, zoom) ->
    x = Math.floor((pt.lon+180)/360*Math.pow(2,zoom))
    y = Math.floor((1-Math.log(Math.tan(pt.lat*Math.PI/180) + 1/Math.cos(pt.lat*Math.PI/180))/Math.PI)/2 *Math.pow(2,zoom))
    return x: x, y: y, z: zoom

  project: (latLon) ->
    d = Math.PI / 180
    max = this.MAX_LATITUDE
    lat = Math.max Math.min(max, latLon.lat), -max
    x = latLon.lon * d
    y = lat * d
    y = Math.log(Math.tan((Math.PI / 4) + (y / 2)))
    return x: x , y:y

  transform: (point, scale) ->
    point.x = scale * (@MAP_TRANSFORMATION[0] * point.x + @MAP_TRANSFORMATION[1])
    point.y = scale * (@MAP_TRANSFORMATION[2] * point.y + @MAP_TRANSFORMATION[3])
    point

  latLonToPoint: (latLon, zoom) ->
    projectedPoint = @project latLon
    scale = 256 * Math.pow(2, zoom)
    @transform projectedPoint, scale


  latLonToPointRelative: (latLon, tileOrigin, zoom) ->
    pt = @latLonToPoint latLon, zoom
    return x:pt.x - tileOrigin.x, y:pt.y - tileOrigin.y



class MapTileProducer
  constructor: (@backend) ->
    @projection = new ProjectionUtils()
    @gradient = gradient('#ff0000', '#ff7f00', '#ffff00', '#00ff00', '#00ffff', '#0000ff', '#8b00ff').hsv(256).reverse()
    @minValue = -20
    @maxValue = 50

  DEFAULT_GRID_SIZE: 8
  DEFAULT_ALPHA: 0.5

  createGrid: (docs, n, tileOriginPix, zoom) ->
    # create grid
    grid = new MeasureGrid(n)
    # add docs
    gridWidth = grid.gridWidth()

    for doc in docs
      docPix = @projection.latLonToPointRelative {lat: doc.lat, lon: doc.lon}, tileOriginPix, zoom
      docGridX = Math.floor(docPix.x / gridWidth)
      docGridY = Math.floor(docPix.y / gridWidth)
      grid.addValue(docGridX, docGridY, doc.last.temperature) if doc.last
    grid

  drawPoint: (ctx, tileOriginPix, zoom, doc) ->
    docPix = @projection.latLonToPointRelative {lat: doc.lat, lon: doc.lon}, tileOriginPix, zoom
    ctx.fillStyle = "#FF0000"
    ctx.fillRect docPix.x-3, docPix.y-3, 6, 6

  drawGrid: (ctx, grid, n, alpha) ->
    gridWidth = grid.gridWidth()

    a = 256 / (@maxValue - @minValue)
    b = -@minValue * a

    # fill canvas
    for i in [0...n]
      for j in [0...n]
        val = grid.valueAt(i, j)
        if !isNaN(val)
          val = @minValue if val < @minValue
          val = @maxValue if val > @maxValue
          color = @gradient[ Math.floor(a * val + b) ]
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
    ctx.fillText('weather-api.lc6.net', 0, 0)

  produceMap: (tile, gridSize, drawStations, alpha, callback)  ->

    tileOriginLatLon = @projection.tileToLatLon tile
    tileMaxLatLon = @projection.tileToLatLon { x: tile.x + 1, y: tile.y + 1, z: tile.z }
    tileOriginPix = @projection.latLonToPoint tileOriginLatLon, tile.z

    canvas = new Canvas 256, 256
    ctx = canvas.getContext '2d'

    query = $and: [ {lat: { $gte: tileMaxLatLon.lat }},
      { lat: { $lt: tileOriginLatLon.lat }},
      { lon: { $gte: tileOriginLatLon.lon}},
      { lon: { $lt: tileMaxLatLon.lon }}  ]

    @backend.withConnection (err, db) =>
      return callback err if err
      db.collection('stations').find(query).toArray (err, docs) =>
        db.close()
        return callback err if err

        # draw grid
        grid = @createGrid(docs, gridSize, tileOriginPix, tile.z)
        grid.meanValues()
        grid.interpolateCells()
        @drawGrid(ctx, grid, gridSize, alpha)

        # draw station locations
        @drawPoint(ctx, tileOriginPix, tile.z, doc) for doc in docs if drawStations

        # finally apply watermarks
        # @applyWatermark ctx

        callback null, canvas.toBuffer()

  sendError: (res, err) ->
    winston.log 'error', 'Cannot produce tile' + (err.message || err)
    res.status(500).send('oops, an error occured')

  registerRoutes: (app) ->
    app.get '/map/temperature/:z/:x/:y.png', (req, res) =>
      tile = x:parseInt(req.params.x), y:parseInt(req.params.y), z:parseInt(req.params.z)
      gridSize = if req.query.grid then parseInt(req.query.grid) else @DEFAULT_GRID_SIZE
      stations = !!req.query.stations
      alpha = if req.query.alpha then parseFloat(req.query.alpha) else @DEFAULT_ALPHA

      @produceMap tile, gridSize, stations, alpha, (err, pngBuf) =>
        return @sendError(res, err) if err

        res.set 'Content-Type', 'image/png'
        res.send pngBuf



exports.MapTileProducer = MapTileProducer
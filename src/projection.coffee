mathjs = require 'mathjs'

class Projection
  constructor: ->

  MAX_LATITUDE: 85.0511287798,
  MAP_TRANSFORMATION: [ 0.5 / Math.PI,  0.5,  -0.5 / Math.PI, 0.5]

  tileToLatLon: (tile) ->
    n = mathjs.pow(2, tile.z)
    lonDeg = tile.x / n * 360.0 - 180.0
    latRad = mathjs.atan( mathjs.sinh( Math.PI * ( 1 - 2 * tile.y / n)))
    latDeg = latRad * 180.0 / Math.PI
    return {lat: latDeg, lon: lonDeg }

  latLonToTile: (pt, zoom) ->
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

exports.Projection = Projection

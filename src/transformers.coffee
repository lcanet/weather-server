_ = require 'lodash'
winston = require 'winston'
moment = require('moment')
momentTz = require('moment-timezone')
SunCalc = require 'suncalc'
iconifier = require './iconifier'

copy = (source, dest, properties) ->
  for key in properties
    dest[key] = source[key] if source[key]?
  dest

appendSunCalcs = (dest, tz = 'GMT') ->
  date = moment(new Date()).tz('GMT')
  dest.sunTimes = SunCalc.getTimes date, dest.lat, dest.lon
  _.each dest.sunTimes, (value, key) ->
    dest.sunTimes[key] = moment(value).tz(tz).format()
  dest


computeRelativeHumidity = (metar) ->
  Math.floor 100 - 5 * (metar.temperature - metar.dewPoint)


makeBasic = (source) ->
  dest = copy source, {}, ['code', 'lat', 'lon', 'name', 'city']
  if source.lastUpdate and source.tz
    dest.lastUpdate = moment(source.lastUpdate).tz(source.tz).format()
  else
    dest.lastUpdate = source.lastUpdate
  dest

toBare = (source) ->
  dest = makeBasic source
  dest.altitude = source.alt
  if source.last
    copy source.last, dest, ['wind', 'visibility', 'clouds', 'temperature', 'dewPoint', 'altimeter', 'cavok', 'nosig', 'conditions', 'clear', 'visibilityInDirection']
    dest.humidity = computeRelativeHumidity source.last
  dest

toBareMetar = (source) ->
  dest = toBare source
  if source.last
    dest.metar = source.last.metar
  dest

toSimple = (source) ->
  dest = makeBasic source
  appendSunCalcs dest, source.tz
  if source.last
    copy source.last, dest, ['temperature', 'wind']
    dest.icon = iconifier source.last, source
    dest.humidity = computeRelativeHumidity source.last
  dest

toClassic = (source) ->
  source.humidity = computeRelativeHumidity source.last if source?.last
  appendSunCalcs source, source.tz

transform = (source, destFormat='bare') ->
  if _.isArray(source)
    _.map source, (item) ->
      transform item, destFormat
  else
    if destFormat is 'bare'
      toBare source
    else if destFormat is 'bareMetar'
      toBareMetar source
    else if destFormat is 'simple'
      toSimple source
    else if destFormat is 'classic'
      toClassic source
    else
      winston.log 'warn', 'Unknown format to transform %s', destFormat
      source


transformGeoNear = (source, destFormat='bare') ->
  obj = transform(source.obj, destFormat)
  obj.distance = source.dis
  obj

transformGeoNears = (source, destFormat='bare', limit=1) ->
  _.map source, (item) -> transformGeoNear(item, destFormat)

transformHistory = (source, destFormat='bare') ->
  # no special format, just remove special fields
  _.map source, (x) ->
    _.omit x, '_id'

getGeojsonGeometry = (source) ->
  type: 'Point', coordinates: [source.lon, source.lat]

getGeojsonProperties = (source, format = 'simple') ->
  dest = copy source, {}, ['code', 'name', 'city']
  if format is 'simple'
    if source.last
      copy source.last, dest, ['temperature', 'wind']
      dest.icon = iconifier source.last, source
      dest.humidity = computeRelativeHumidity source.last
  dest

toGeoJsonFeature = (source, format = 'simple') ->
  type: 'Feature', geometry: getGeojsonGeometry(source), properties: getGeojsonProperties(source, format)

toGeoJson = (source, format = 'simple') ->
  type: 'FeatureCollection', features: _.map source, (x) -> toGeoJsonFeature(x, format)

exports.transform = transform
exports.transformGeoNear = transformGeoNear
exports.transformGeoNears = transformGeoNears
exports.transformHistory = transformHistory
exports.toGeoJson = toGeoJson

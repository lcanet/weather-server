_ = require 'lodash'
winston = require 'winston'

copy = (source, dest, properties) ->
  for key in properties
    if source[key]
      dest[key] = source[key]
  dest

toBare = (source) ->
  dest = {}
  copy source, dest, ['code', 'lat', 'lon', 'name', 'city', 'lastUpdate']
  if source.last
    copy source.last, dest, ['wind', 'visibility', 'clouds', 'temperature', 'dewpoint', 'altimeter', 'cavok', 'nosig', 'conditions', 'clear', 'visibilityInDirection']
  dest

toBareMetar = (source) ->
  dest = toBare source
  if source.last
    dest.metar = source.last.metar
  dest

transform = (source, destFormat='bare') ->
  if _.isArray(source)
    _.map source, (item) ->
      transform item, destFormat
  else
    if destFormat is 'bare'
      toBare source
    else if destFormat is 'bareMetar'
      toBareMetar source
    else if destFormat is 'classic'
      source
    else
      winston.log 'warn', 'Unknown format to transform %s', destFormat
      source


transformGeoNear = (source, destFormat='bare') ->
  obj = transform(source.obj, destFormat)
  obj.distance = source.dis
  obj

transformGeoNears = (source, destFormat='bare', limit=1) ->
  _.map source, (item) -> transformGeoNear(item, destFormat)


exports.transform = transform
exports.transformGeoNear = transformGeoNear
exports.transformGeoNears = transformGeoNears
_ = require 'lodash'
winston = require 'winston'

###
geoNearResults = (array) ->
  obj = cb.results[0].obj
  obj.distance = cb.results[0].dis
###

transform = (source, destFormat='bare') ->
  if _.isArray(source)
    _.map source, (item) ->
      transform item, destFormat
  else
    if destFormat is 'bare'
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
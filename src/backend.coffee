mongo = require 'mongodb'


class Backend
  constructor: ->

  withConnection: (callback) ->
    mongo.MongoClient.connect 'mongodb://192.168.0.2:27017/weather', (err, db) =>
      if err
        callback err
      else
        callback null, db



exports.Backend = Backend

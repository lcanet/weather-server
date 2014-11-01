mongo = require 'mongodb'


class Backend
  constructor: ->

  withConnection: (callback) ->
    if @dbConnection
      callback(null, @dbConnection)
    else
      mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/weather', (err, db) =>
        if err
          callback err
        else
          @dbConnection = db
          callback null, @dbConnection

  withCollection: (collection, callback) ->
    @withConnection (err, db) ->
      if err
        callback err
      else
        callback null, db.collection(collection)



exports.Backend = Backend

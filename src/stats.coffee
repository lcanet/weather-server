_ = require 'lodash'
winston = require 'winston'
async = require 'async'

class Stats
  constructor: (@backend) ->

  # *****************************************************************************
  # statistic items
  # *****************************************************************************
  items: ['history', 'stations', 'stationsWithMeasures', 'dbSize', 'lastUpdates', 'byCountries']

  history: (db, callback) ->
    db.collection('history').count callback

  stations: (db, callback) ->
    db.collection('stations').count callback

  stationsWithMeasures: (db, callback) ->
    db.collection('stations').find( { last: {$exists: true}}).count callback

  dbSize: (db, callback) ->
    db.command {dbStats: 1}, (err, res) ->
      return callback err if err
      callback err, res.storageSize / (1024*1024)

  lastUpdates: (db, callback) ->
    db.collection('stations').aggregate [
      { $match: { lastUpdate: { $exists: 1 } } },
      { $group: { _id: {  year: { $year: "$lastUpdate" }, month: { $month: "$lastUpdate" }, day: { $dayOfMonth: "$lastUpdate" }, hour: { $hour: "$lastUpdate" } }, count: { $sum: 1 } } },
      { $project: {_id: 0, year: '$_id.year', month: '$_id.month', day: '$_id.day', hour: '$_id.hour', count: 1 } },
      { $sort: { 'year': -1, 'month': -1, 'day': -1, 'hour': -1 } }
      ], callback

  byCountries: (db, callback) ->
    db.collection('stations').aggregate [
      { $group: { _id:  '$country', count: { $sum: 1 } } },
      { $project: {_id: 0, country: '$_id', count: 1 } },
      { $sort: { count: -1 } }
      ], callback


  # *****************************************************************************
  # Run
  # *****************************************************************************


  gatherStats: (callback) ->
    @backend.withConnection (err, db) =>
      return callback err if err
      stats = {}
      iteratorRun = (fn, iteratorCallback) =>
        this[fn] db, (err, res) ->
          stats[fn] = res if res
          iteratorCallback err, res

      iteratorFinish = (err, results) ->
        callback err, stats

      async.mapSeries @items, iteratorRun, iteratorFinish


  sendError: (res, err) ->
    winston.log 'error', 'Cannot get stats ' + (err.message || err)
    res.status(500).send('oops, an error occured')

  registerRoutes: (app) ->
    app.get '/stats', (req, res) =>
      @gatherStats (err, stats) =>
        return @sendError(res, err) if err
        res.jsonp stats



exports.Stats = Stats

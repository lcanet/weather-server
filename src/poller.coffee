request = require 'request'
moment = require 'moment'
metar = require './metar'
_ = require 'lodash'
async = require 'async'
winston = require 'winston'
cronJob = require('cron').CronJob

BASE_URL = 'http://weather.noaa.gov/pub/data/observations/metar/cycles/'
#BASE_URL = 'http://laser/~lc/metar/'

###
Insert history entries
###

class InsertHistoryJob
  constructor: (db, @entries) ->
    @collection = db.collection 'history'
    @filteredEntries = []

  insert: (callback) ->
    winston.log 'info', 'Processing %d lines of history insert', @entries.length

    # remove duplicates in batch
    @entries = _.uniq(@entries, false, (entry) -> entry.icao + '_' + entry.date.getTime())
    @filterEntries callback

  filterEntries: (callback) ->
    if @entries.length == 0
      @processFilteredEntries callback
    else
      entry = @entries.pop()
      @collection.count { icao: entry.icao, date: entry.date }, (err, count) =>
        if err
          callback err
        else
          if count is 0
            @filteredEntries.push entry

        @filterEntries callback

  processFilteredEntries: (callback) ->
    winston.log 'info', 'Filtered %d lines of history to write', @filteredEntries.length
    if @filteredEntries.length > 0
      @collection.insert @filteredEntries, {w: 1}, (err, ids) =>
        callback err, @filteredEntries
    else
      callback null, @filteredEntries

###
Update stations collection with up-to-entries if necesseray
###
class UpdateStationJob
  constructor: (db, @entries) ->
    @collection = db.collection('stations')
    @filteredEntries = []

  update: (callback) ->
    winston.log 'info', 'Updating stations with %d entries', @entries.length
    @processNextEntry callback

  needsUpdate: (doc, entry) ->
    !doc.last or !doc.lastUpdate or doc.lastUpdate.getTime() < entry.date.getTime()

  processNextEntry: (callback) ->
    if @entries.length == 0
      winston.log 'info', 'Updated %d stations', @filteredEntries.length
      callback null, @filteredEntries
    else
      entry = @entries.pop()
      @collection.findOne {code: entry.icao}, (err, doc) =>
        if err
          callback err
        else if doc is null
          @processNextEntry callback
        else
          if @needsUpdate doc, entry
            doc.lastUpdate = entry.date
            doc.last = entry
            @filteredEntries.push entry

            @collection.update {code: entry.icao}, doc, {w:1}, (err, result) =>
              if err
                callback err
              else
                @processNextEntry callback
          else
            @processNextEntry callback


###
  Main poller
###
class Poller
  constructor: (@backend) ->

  processEntries: (entries, stats, callback) ->
    stats.nbEntries = entries.length
    @backend.withConnection (err, db) =>
      if err
        callback err
      else
        job = new InsertHistoryJob db, entries
        job.insert (err, insertedEntries) =>
          if err
            db.close()
            callback err
          else
            stats.nbHistoryEntries = insertedEntries.length
            job = new UpdateStationJob db, insertedEntries
            job.update (err, updateEntries) ->
              if err
                db.close()
                callback err
              else
                stats.nbStationsUpdated = updateEntries.length
                db.close()
                callback null, stats

  pollOneFile: (file, callback) ->
    url = BASE_URL + file
    winston.log 'info', 'Downloading cycle file %s', url
    request url, (err, resp, body) =>
      if err
        callback err
      else
        stats = nbLines: 0, nbErrors: 0, errors: [], file: file
        currentDate = null
        entries = []

        body.split('\n').forEach (line) ->
          if line
            if (line.match(/([0-9]{4})\/([0-9]{2})\/([0-9]{2}) ([0-9]{2}):([0-9]{2})/))
              currentDate = moment(line + 'Z', 'YYYY/MM/DD HH:mmZ').toDate()
            else
              try
                decoded = metar.decode(line)
                decoded.date = currentDate
                decoded.metar = line
                entries.push decoded
                stats.nbLines++
              catch err
                stats.nbErrors++
                stats.errors.push err

        @processEntries entries, stats, callback

  pollDir: (callback) ->
    pollFn = (file, cb) =>
      if file < 10
        file = '0' + file

      @pollOneFile(file + 'Z.TXT', cb)

    # didnt manage to pass 2 closures in a row ?!
    async.mapSeries(_.range(24), pollFn, callback)

  startPoller: ->
    pollHandler = () =>
      winston.info 'Polling of metar cycles directory'
      @pollDir (err) ->
        if (err)
          winston.error 'Polling failed : ' + err

    new cronJob('00 20 * * * *', pollHandler).start()
    winston.info 'Poller started'

exports.Poller = Poller


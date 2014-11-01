request = require 'request'
moment = require 'moment'
metar = require './metar'
_ = require 'lodash'
async = require 'async'
cronJob = require('cron').CronJob

# BASE_URL = 'http://weather.noaa.gov/pub/data/observations/metar/cycles/'
BASE_URL = 'http://laser/~lc/metar/'

###
Insert history entries
###

class InsertHistoryJob
  constructor: (@collection, @entries) ->
    @filteredEntries = []

  insert: (callback) ->
    console.log 'check history ' + @entries.length
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
    console.log 'filtered ' + @filteredEntries.length
    if @filteredEntries.length > 0
      @collection.insert @filteredEntries, {w: 1}, (err, ids) =>
        callback err, @filteredEntries
    else
      callback null, @filteredEntries

###
Update stations collection with up-to-entries if necesseray
###
class UpdateStationJob
  constructor: (@collection, @entries) ->
    @filteredEntries = []

  update: (callback) ->
    console.log 'Updating ' + @entries.length
    @processNextEntry callback

  needsUpdate: (doc, entry) ->
    !doc.last or !doc.lastUpdate or doc.lastUpdate.getTime() < entry.date.getTime()

  processNextEntry: (callback) ->
    if @entries.length == 0
      console.log 'Updated ' + @filteredEntries.length
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
    @processHistoryEntries entries, stats, callback

  processUpdateEntries: (entries, stats, callback) ->
    # first filter entries not present
    @backend.withCollection 'stations', (err, col) =>
      if err
        callback err
      else
        job = new UpdateStationJob col, entries
        job.update (err, updateEntries) ->
          if err
            callback err
          else
            stats.nbStationsUpdated = updateEntries.length
            callback null ,stats

  processHistoryEntries: (entries, stats, callback) ->
    # first filter entries not present
    @backend.withCollection 'history', (err, col) =>
      if err
        callback err
      else
        job = new InsertHistoryJob col, entries
        job.insert (err, insertedEntries) =>
          if err
            callback err
          else
            stats.nbHistoryEntries = insertedEntries.length
            @processUpdateEntries insertedEntries, stats, callback

  pollOneFile: (file, callback) ->
    url = BASE_URL + file
    console.log 'Downloading ' + url
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
      @pollDir()

    new cronJob('00 3 * * * *', pollHandler).start()

exports.Poller = Poller

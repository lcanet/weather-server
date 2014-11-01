onHeaders = require 'on-headers'
winston = require 'winston'


module.exports = () ->
  hdrName = 'X-Response-Time'

  return (req, res, next) ->
    start = process.hrtime()
    onHeaders res, ->
      if !this.getHeader(hdrName)
        diff = process.hrtime(start)
        ms = (diff[0] * 1e3 + diff[1] * 1e-6).toFixed(3)
        this.setHeader(hdrName, ms + ' ms')
        winston.debug (req.path + ' - ' + ms + ' ms'), {ip: req.ip, time: ms, path: req.path }

    next()



_ = require 'lodash'
moment = require('moment')
momentTz = require('moment-timezone')

stateOktas = (state) ->
  switch state
    when 'OVC' then 8
    when 'BKN' then 6
    when 'SCT' then 4
    when 'FEW' then 2
    when 'NSC' then 1
    when 'CLR' then 0
    when 'SKC' then 0
    else 0

cloudOktas = (metar) ->
  oktas = 0
  if metar.cavok or metar.clear
    oktas = 0
  else
    _.each metar.clouds, (cl) ->
      oktas = Math.max(oktas, stateOktas(cl.type))
  oktas

condDesc = (metar, descriptors...) ->
  !!_.find metar.conditions, (cond) -> _.contains(descriptors, cond.descriptor)

condType = (metar, types...) ->
  !!_.find metar.conditions, (cond) -> _.contains(types, cond.type)

iconify = (metar, station) ->
  icons = []

  localHour = moment(metar.date).tz(station.tz).hour()
  isNight = localHour >= 22 || localHour < 6
  isDay = !isNight
  cloud = cloudOktas metar

  if isNight and 0 < cloud < 8
    icons.push 'night'

  if isDay and 0 < cloud < 8
    icons.push 'sunny'

  if metar.temperature <= 1 or condDesc(metar, 'FZ')
    icons.push 'frosty'

  if condType(metar, 'RA', 'DZ', 'UP') and condDesc(metar, 'BL', 'SH')
    icons.push 'showers'

  if 0 < cloud <  8
    icons.push 'basecloud'

  if cloud is 8
    icons.push 'cloud'

  # todo empty desc
  if condType(metar, 'RA', 'UP') and condDesc(metar, 'MI', 'PR', 'BC', 'DR')
    icons.push 'rainy'

  if condType(metar, 'BR', 'FG', 'HZ')
    icons.push 'mist'

  if condType(metar, 'DZ')
    icons.push 'drizzle'

  if condType(metar, 'SN', 'SG', 'IC', 'PL')
    icons.push 'snowy'

  if isNight and cloud is 0
    icons.push 'moon'

  if condType(metar, 'GR', 'GS')
    icons.push 'hail'

  if isDay and cloud is 0
    icons.push 'sun'

  if condDesc(metar, 'TS')
    icons.push 'thunder'

  if metar.wind?.speed > 20
    icons.push 'windy'

  icons


module.exports = iconify
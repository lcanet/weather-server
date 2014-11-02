_ = require 'lodash'
moment = require('moment')
momentTz = require('moment-timezone')
SunCalc = require 'suncalc'

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
  icon = ''

  date = moment(metar.date)
  localTime = moment(metar.date).tz(station.tz)
  times = SunCalc.getTimes metar.date, station.lat, station.lon
  dawn = moment(times.dawn)
  dusk = moment(times.dusk)

  isDay = dawn.isBefore(date) && dusk.isAfter(date)
  isNight = !isDay
  cloud = cloudOktas metar
  wind = metar.wind?.speed
  gust = metar.wind?.gust

  # ### CLOUD BASIC

  if isDay
    if cloud is 0
      icon = 'day-sunny'
    else if 0 < cloud < 8
      icon = 'day-cloudy'
    else
      icon = 'cloudy'

  if isNight
    if cloud is 0
      icon = 'night-clear'
    else
      icon = 'night-cloudy'

  # ### WINDS

  if wind > 20
    if cloud is 8
      icon = 'cloudy-windy'
    else if isDay and cloud > 0
      icon = 'day-cloud-windy'
    else if isNight and cloud > 0
      icon = 'night-cloudy-windy'

  if gust > 30
    if cloud is 8
      icon = 'cloudy-gusts'
    else if isDay and cloud > 0
      icon = 'day-cloud-gusts'
    else if isNight and cloud > 0
      icon = 'night-cloudy-gusts'


  # ### CONDITION

  # Hail
  if condType(metar, 'GR', 'GS')
    if cloud is 8
      icon = 'hail'
    else if isDay
      icon = 'day-hail'
    else
      icon = 'night-hail'

  # Fog
  if condType(metar, 'FG', 'BR', 'HZ')
    if cloud is 8
      icon = 'fog'
    else if isDay
      icon = 'day-fog'
    else
      icon = 'night-fog'

  # Rain
  if condType(metar, 'RA', 'DZ', 'UP')
    if cloud is 8
      if wind < 15
        icon = 'rain-wind'
      else
        icon = 'rain'
    else if isDay
      if wind < 15
        icon = 'day-rain-wind'
      else
      icon = 'day-rain'
    else
      if wind < 15
        icon = 'night-rain-wind'
      else
      icon = 'night-rain'

  # Snow
  if condType(metar ,'SN', 'SG', 'IC', 'PL')
    if cloud is 8
      icon = 'snow'
    else if isDay
      icon = 'day-snow'
    else
      icon = 'night-snow'

  # ### CONDITION TYPES

  thunderstorm = condDesc(metar, 'TS') or condType(metar, 'TS')
  showers = condDesc(metar, 'SH') or condType(metar, 'SH')

  if thunderstorm && showers
    if cloud is 8
      icon = 'storm-showers'
    else if isDay
      icon = 'day-storm-showers'
    else
      icon = 'night-storm-showers'
  else if thunderstorm
    if cloud is 8
      icon = 'thunderstorm'
    else if isDay
      icon = 'day-thunderstorm'
    else
      icon = 'night-thunderstorm'
  else if showers
    if cloud is 8
      icon = 'showers'
    else if isDay
      icon = 'day-showers'
    else
      icon = 'night-showers'

  icon



module.exports = iconify





















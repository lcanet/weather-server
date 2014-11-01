_ = require 'lodash'

# Normalize to knots
normalizeSpeed = (speed, unit = 'KT') ->
  if unit is 'KT'
    speed
  else if unit is 'KTS'
    speed
  else if unit is 'MPS'
    speed * 3600 / 1852
  else if unit is 'KMH'
    speed / 1.852

# Normalize to meters
normalizeDistance = (dist, unit = 'M') ->
  if unit is 'M'
    dist
  else if unit is 'SM'
    dist * 1.609
  else
    dist

parseTemperature = (temp) ->
  if temp.charAt(0) is 'M'
    temp = '-' + temp.substring(1)
  return parseInt temp


CONDITIONS = {
  MI: "shallow",
  PR: "partial",
  BC: "patches",
  DR: "low drifting",
  BL: "blowing",
  SH: "showers",
  TS: "thunderstorm",
  FZ: "freezing",
  RA: "rain",
  DZ: "drizzle",
  SN: "snow",
  SG: "snow grains",
  IC: "ice crystals",
  PL: "ice pellets",
  GR: "hail",
  GS: "small hail",
  UP: "unknown precipitation",
  FG: "fog",
  VA: "volcanic ash",
  BR: "mist",
  HZ: "haze",
  DU: "widespread dust",
  FU: "smoke",
  SA: "sand",
  PY: "spray",
  SQ: "squall",
  PO: "dust or sand whirls",
  DS: "duststorm",
  SS: "sandstorm",
  FC: "funnel cloud"
};

CONDITIONS_REGEX = '^(\\+|-|VC)?(' + (_.keys(CONDITIONS).join('|')) + ')+$'

CLOUD_COLORS = {
  BLU: 'blue',
  WHT: 'white',
  GRN: 'green',
  YLO: 'yellow',
  AMB: 'amber',
  RED: 'red',
  BLACK: 'black'

}

CLOUD_COLORS_REGEX = '^(' + _.keys(CLOUD_COLORS).join('|') + ')$';

class MetarParser
  constructor: (line) ->
      @tokens = line.split(' ')
      @index = -1
      @result = {}
      @visibilityCarry = 0


  parse: ->
    @parseToken(token, index) for token, index in @tokens
    @result

  parseToken: (token, index) ->

    if index is 0
      @result.icao = token
    else if index is 1 and (match = token.match(/^[0-3][0-9][0-9]{4}Z$/))
      @result.day = parseInt(match[0].substring(0,2))
      @result.hour = parseInt(match[0].substring(2,4)) + parseInt(match[0].substring(4,6))*60
    else if token is 'AUTO'
      @result.automatic = true
    else if token is 'COR'
      @result.corrected = true
    else if match = token.match(/^([0-9\/]{3}|VRB)([0-9\/]{2,})(G[0-9]+)?(MPS|KT|KMH|KTS)$/)
      @parseWind(match)
    else if match = token.match(/^([0-9]{3})V([0-9]{3})$/)
      @parseVariableWindDirection(match)
    else if token is '1'
      @visibilityCarry = 1
    else if token is '2'
      @visibilityCarry = 2
    else if match  = token.match(/^([0-9]{4})(NDV)?$/)
      @result.visibility = normalizeDistance(parseInt(match[1]), 'M')
    else if match = token.match(/^([0-9]+)(\/[0-9]+)?SM$/)
      @parseVisibility(match)
      @visibilityCarry = 0
    else if token.match(/^M?[0-9]+\/(M?[0-9]+)?$/)
      @parseTemperatures(token)
    else if token.match(/^[AQ][0-9]{2}\.?[0-9]{2}$/)
      @parseAltimer(token)
    else if match = token.match(/^(SKC|CLR|NSC|FEW|SCT|BKN|OVC|VV)([0-9]+)?(.*)?\/*$/)
      @parseClouds(match)
    else if token.match(/^R[0-9]+[LRC]?\/.*$/)
      ### skip unsupported runway visibility ###
    else if token is 'CLR' or token is 'NCD'
      @result.clear = true
    else if token.match(CONDITIONS_REGEX)
      @parseCondition(token)
    else if token.match(CLOUD_COLORS_REGEX)
      @result.color = token
    else if token is 'CAVOK'
      @result.cavok = true
    else if token is 'NOSIG'
      @result.cavok = true
    else if token is 'RMK'
      @inRemarks = true
      @inTempo = false
    else if token is 'TEMPO' or token is 'BECMG' or token.match(/^TL[0-9]{4}$/)
      @inRemarks = false
      @inTempo = true
    else if token.match(/^\/+$/)
    else if !@inRemarks && !@inTempo
      console.log('UNKNOWN TOKEN ' + token + ' for ' + @tokens.join(' '))

  parseWind: (match) ->
    unit = match[4]
    wind = {
      speed: normalizeSpeed(parseInt(match[2]), unit)
    }
    if match[1] is 'VRB'
      wind.variable = true
    else
      wind.direction = parseInt(match[1])

    if match[3]
      wind.gust = normalizeSpeed(parseInt(match[3].substring(1)), unit)

    @result.wind = wind


  parseVariableWindDirection: (match) ->
    if (!@result.wind)
      @result.wind = {}
    @result.wind.variableDirection = from: parseInt(match[1]), to: parseInt(match[2])

  parseVisibility: (match) ->
      visibFrac = parseInt(match[1])
      if (match[2])
        visibFrac = visibFrac / parseInt(match[2].substring(1))
      @result.visibility = normalizeDistance(@visibilityCarry + visibFrac, 'SM')
      @visibilityCarry = 0

  parseTemperatures: (token) ->
    parts = token.split('/')
    @result.temperature = parseTemperature(parts[0])
    @result.dewPoint = parseTemperature(parts[1])

  parseAltimer: (token) ->
    value = parseInt(token.substring(1).replace('.', ''))
    if token.charAt(0) == 'A'
      value = value / 100 * 33.86
    @result.altimeter = value

  ### TODO vertical visibility VVhhh suffix ###
  parseClouds: (match) ->
    if !@result.clouds
      @result.clouds = []

    cloud = type: match[1]
    if match[2]
      cloud.altitude = parseInt(match[2]) * 100

    if (match[3])
      cloud.cloudType = match[3]

    @result.clouds.push(cloud)

  parseCondition: (match) ->
    if !@result.conditions
      @result.conditions= []

    cond = {}
    if match.charAt(0) is '-'
      cond.intensity = 'light'
      match = match.substring(1)
    else if match.charAt(0) is '+'
      cond.intensity = 'heavy'
      match = match.substring(1)
    else if match[0..2] is 'VC'
      cond.vicinity = true
      match = match.substring(2)

    cond.type = match
    if CONDITIONS[cond.type]
      cond.label = CONDITIONS[cond.type]

    @result.conditions.push(cond)

exports.decode = (metar) ->
  new MetarParser(metar).parse()
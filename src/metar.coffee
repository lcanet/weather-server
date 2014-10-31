
mpsToKt = (mps) ->
  mps * 3600 / 1852


decodeToken = (result, token, index) ->
  if index is 0
    result.icao = token
  else if index is 1 and token.match(/[0-3][0-9][0-9]{4}Z/)
    ### Date ###
    result.day = parseInt(token.substring(0,2))
    result.hour = parseInt(token.substring(2,4)) + parseInt(token.substring(4,6))*60
  else if token.match(/[0-9]{5,}(MPS|KT)/)
    ### Wind ###
    mps = token.match(/MPS$/)
    speed = parseInt(token[2..(token.length - mps ? 4 : 3)])
    result.wind =
      direction: parseInt(token[0..2])
      speed: speed

  result


exports.decode = (metar) ->
  decoded = {}
  decodeToken(decoded, token, index) for token, index in  metar.split(' ')

  decoded

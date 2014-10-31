metar = require '../src/metar'

describe "METAR Decoder", ->

  it "Should read ICAO code", ->
    r = metar.decode('KAIK 302355Z AUTO 00000KT 10SM CLR 14/07 A3000 RMK AO2 LTG DSNT S PN0')
    expect(r.icao).toBe 'KAIK'

  it 'Should read hour', ->
    r = metar.decode('KAIK 302355Z AUTO 00000KT 10SM CLR 14/07 A3000 RMK AO2 LTG DSNT S PN0')
    expect(r.day).toBe 30
    expect(r.hour).toBe 3323


  it 'Should read wind', ->
    r = metar.decode('KHYR 302346Z AUTO 32005KT 10SM FEW022 BKN048 OVC055 03/01 A3012 RMK AO2 RAB2255E38 P0000 T00280006')
    expect(r.wind.direction).toBe 320
    expect(r.wind.speed).toBe 5

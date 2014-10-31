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

  it 'Should read damn russian wind', ->
    r = metar.decode('UMMS 310000Z 29002MPS 1600 BCFG BR BKN022 M03/M03 Q1022 R31/CLRD// TEMPO 0300 FZFG')
    expect(r.wind.direction).toBe 290
    expect(r.wind.speed).toBeCloseTo 3.8876, 1

  it 'Should read variable wind', ->
    r = metar.decode('KCQT 302347Z AUTO VRB03KT 10SM CLR 21/15 A2993 RMK AO2 SLP134 T02110150 10272 20211 56006')
    expect(r.wind.variable).toBe true
    expect(r.wind.speed).toBe 3

  it 'Should read wind gusts', ->
    r = metar.decode('KHOB 302350Z 03012G18KT 10SM SKC 22/08 A3020')
    expect(r.wind.speed).toBe 12
    expect(r.wind.gust).toBe 18

  it 'Should read wind directions', ->
    r = metar.decode('CBBC 302350Z AUTO 15008KT 120V180 9SM SCT024 BKN030 BKN042 12/09 A2965 RMK PRESFR SLP041')
    expect(r.wind.variableDirection.from).toBe 120
    expect(r.wind.variableDirection.to).toBe 180

  it 'Should read metric visibility', ->
    r = metar.decode('LFMN 310000Z 33009KT 9999 SCT030 13/09 Q1024 NOSIG')
    expect(r.visibility).toBe 9999

  it 'Should read statue miles visibility', ->
    r = metar.decode('KDYB 302355Z AUTO 00000KT 4SM BR CLR 15/14 A2996 RMK AO1')
    expect(r.visibility).toBeCloseTo 6.436, 2

  it 'Should read fractional visibility', ->
    r = metar.decode('KMLP 302345Z AUTO 15009KT 1 1/2SM BR FEW001 BKN055 03/03 A3007 RMK AO2 T00280028')
    expect(r.visibility).toBeCloseTo  2.4135

  it 'Should parse  temperatures', ->
    r = metar.decode('KSUN 302347Z 18005KT 10SM SCT070 BKN160 15/M01 A3016')
    expect(r.temperature).toBe 15
    expect(r.dewPoint).toBe -1

  it 'Should parse temperatures without dewpoints', ->
    r = metar.decode('CYUS 302345Z AUTO 17007KT 9SM CLR M23/ A3019 RMK ICG PAST HR')
    expect(r.temperature).toBe -23

  it 'Should parse  clouds', ->
    r = metar.decode('CYCY 302350Z AUTO 30012KT 2SM BR FEW005 OVC012 M07/M08 A3000 RMK VIS VRB 1 1/2-3 ICG SLP162')
    expect(r.clouds.length).toBe 2
    expect(r.clouds[0].type).toBe 'FEW'
    expect(r.clouds[1].altitude).toBe 1200

  it 'Should parse  clouds type', ->
    r = metar.decode('AGGH 310000Z 07008KT 9999 FEW021CB 32/24 Q1010')
    expect(r.clouds.length).toBe 1
    expect(r.clouds[0].type).toBe 'FEW'
    expect(r.clouds[0].altitude).toBe 2100
    expect(r.clouds[0].cloudType).toBe 'CB'


  it 'Should parse conditions', ->
    r = metar.decode('KDYB 302355Z AUTO 00000KT 4SM BR CLR 15/14 A2996 RMK AO1')
    expect(r.conditions.length).toBe 1
    expect(r.conditions[0].type).toBe 'BR'
    expect(r.conditions[0].label).toBe 'mist'

  it 'Should parse conditions 2', ->
    r = metar.decode('CYUA 302345Z AUTO 25004KT 6SM -SN M09/ A2991')
    expect(r.conditions.length).toBe 1
    expect(r.conditions[0].type).toBe 'SN'
    expect(r.conditions[0].label).toBe 'snow'
    expect(r.conditions[0].intensity).toBe 'light'

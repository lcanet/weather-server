_ = require 'lodash'
mathjs = require 'mathjs'

class MeasureGrid
  constructor: (@n, @tileWidth = 256) ->
    @grid = []
    for i in [0...@n]
      line = []
      for j in [0...@n]
        line.push []
      @grid.push line

  # The size of one cell of this grid in a tile
  gridWidth: ->
    @tileWidth / @n

  addValue: (i, j, value) ->
    @grid[i][j].push value if !isNaN(value) and !_.isUndefined(value)

  valueAt: (i,j) ->
    @grid[i][j]

  average: (tab) ->
    NaN if tab.length is 0
    (_.reduce tab, ((sum, x) -> sum + x), 0) / tab.length

  # mean values in the grid
  meanValues: ->
    for i in [0...@n]
      for j in [0...@n]
        @grid[i][j] = @average(@grid[i][j])

  interpolateCellNeighbours: (i, j, delta=1) ->
    value = 0
    nb = 0
    for k in [i-delta..i+delta]
      for l in [j-delta..j+delta]
        if k >= 0 and l >= 0 and k < @n and l < @n and !isNaN(@grid[k][l])
          value += @grid[k][l]
          nb++
    if nb is 0 then NaN else value / nb

  dist: (i1, j1, i2, j2) ->
    mathjs.sqrt( (i1-i2)*(i1-i2) + (j1-j2)*(j1-j2))

  w: (i1, j1, i2, j2, p = 1) ->
    1 / mathjs.pow(@dist(i1, j1, i2, j2), p)


  allWNorm: (i, j, p = 1) ->
    s = 0
    for k in [0...@n]
      for l in [0...@n]
        s += @w(i, j, k, l, p) if !isNaN(@grid[k][l])
    s

  interpolateCellIDW: (i, j, p = 1) ->
    n = @allWNorm i, j, p
    s = 0
    for k in [0...@n]
      for l in [0...@n]
        s += @w(i, j, k, l, p) * @grid[k][l]  if !isNaN(@grid[k][l])
    if n  is 0 then NaN else s / n

  interpolateGrid: (cellFn) ->
    newGrid = []
    for i in [0...@n]
      newGrid[i] = []
      for j in [0...@n]
        newGrid[i][j] = if !isNaN(@grid[i][j]) then @grid[i][j] else cellFn(i, j)
    @grid = newGrid


  # interpolate empty cell value based on their 8 nearest neighbour
  interpolateNeighbours: () ->
    @interpolateGrid (i, j) =>
      @interpolateCellNeighbours(i, j, 1)

  # Interpolate using IDW
  interpolateIDW: (p) ->
    @interpolateGrid (i, j) =>
      @interpolateCellIDW(i, j, p)



exports.MeasureGrid = MeasureGrid

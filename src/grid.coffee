_ = require 'lodash'

class MeasureGrid
  constructor: (@n) ->
    @grid = []
    for i in [0...@n]
      line = []
      for j in [0...@n]
        line.push []
      @grid.push line

  gridWidth: ->
    256 / @n

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

  interpolatePos: (i, j) ->
    value = 0
    nb = 0
    for k in [i-1..i+1]
      for l in [j-1..j+1]
        if k >= 0 and l >= 0 and k < @n and l < @n and !isNaN(@grid[k][l])
          value += @grid[k][l]
          nb++
    if nb is 0 then NaN else value / nb

  # interpolate empty cell value based on their 8 nearest neighbour
  interpolateCells: () ->
    newGrid = []
    for i in [0...@n]
      newGrid[i] = []
      for j in [0...@n]
        newGrid[i][j] = if !isNaN(@grid[i][j]) then @grid[i][j] else @interpolatePos(i, j)
    @grid = newGrid


exports.MeasureGrid = MeasureGrid

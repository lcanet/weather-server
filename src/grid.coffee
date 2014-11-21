_ = require 'lodash'
mathjs = require 'mathjs'

class MeasureGrid
  constructor: (@n) ->
    @grid = null

  valueAt: (i,j) ->
    @grid[i][j]

  gridSize: () ->
    @n

  # The size of one cell of this grid in a tile
  gridWidth: ->
    256 / @n

  fillFromValues: (samples, p = 1) ->
    @grid = []
    for i in [0...@n]
      @grid[i] = []
      for j in [0...@n]
        @grid[i][j] = @interpolateCell i, j, samples, p

  interpolateCell: (i, j, samples, p = 1) ->
    # first check for samples in same cells
    nb = 0
    s = 0
    for sample in samples
      if sample.x is i and sample.y is j
        nb++
        s += sample.value

    if nb isnt 0
      return s / nb

    # else proceed with interpolation
    norm = @allWNorm i, j, samples, p
    s +=  @w(i, j, sample, p) * sample.value for sample in samples
    if norm is 0 then NaN else s / norm

  allWNorm: (i, j, values, p = 1) ->
    s = 0
    s += @w(i, j, sample, p) for sample in values
    s

  w: (i, j, sample, p = 1) ->
    1 / mathjs.pow(@dist(i, j, sample.x, sample.y), p)

  dist: (i1, j1, i2, j2) ->
    mathjs.sqrt( (i1-i2)*(i1-i2) + (j1-j2)*(j1-j2))



exports.MeasureGrid = MeasureGrid

MeasureGrid = require('../src/grid').MeasureGrid

describe 'Measure Grid', ->
    it 'should expose get/set', ->
      grid = new MeasureGrid(4)
      grid.addValue(0,0, 40)
      grid.addValue(0,1, 42)
      grid.addValue(0,1, 45)
      expect(grid.valueAt(0,0)).toEqual [40]
      expect(grid.valueAt(0,1)).toEqual [42, 45]

    it 'Should expose grid width', ->
      expect(new MeasureGrid(4).gridWidth()).toBe 64
      expect(new MeasureGrid(8).gridWidth()).toBe 32

    it 'Should average values', ->
      grid = new MeasureGrid(4)
      grid.addValue(0,0, 40)
      grid.addValue(0,0, 20)
      grid.meanValues()
      expect(grid.valueAt(0,0)).toBe 30

    it 'Should interpolate values', ->
      grid = new MeasureGrid(4)
      grid.addValue(0,0, 40)
      grid.addValue(1,1, 20)
      grid.meanValues()
      grid.interpolateNeighbours()

      expect(grid.valueAt(0,1)).toBe 30
      expect(grid.valueAt(1,0)).toBe 30

    it 'Should interpolate using IDW', ->
      grid = new MeasureGrid(3)
      grid.addValue(0,0, 40)
      grid.addValue(1,1, 20)
      grid.meanValues()
      grid.interpolateIDW 1
      expect(grid.valueAt(0,1)).toBe 30
      expect(grid.valueAt(1,0)).toBe 30
      expect(grid.valueAt(2,0) == grid.valueAt(0,2)).toBe true   # symetry
      expect(grid.valueAt(2, 0)).toBeLessThan 30

MeasureGrid = require('../src/grid').MeasureGrid

describe 'Measure Grid', ->
    it 'should expose get/set', ->
      grid = new MeasureGrid(4)
      expect(grid.gridWidth()).toBe 64
      expect(grid.gridSize()).toBe 4

    it 'Should fill from data', ->
      grid = new MeasureGrid(2)
      values = [
        { x:0, y:0, value:1},
        { x:0, y:1, value:2},
        { x:1, y:0, value:3}
        { x:1, y:1, value:4}
      ]
      grid.fillFromValues(values)
      expect(grid.valueAt(0,0)).toBe 1
      expect(grid.valueAt(0,1)).toBe 2
      expect(grid.valueAt(1,0)).toBe 3
      expect(grid.valueAt(1,1)).toBe 4

    it 'Should mean multiple data points in a cell', ->
      grid = new MeasureGrid(2)
      values = [
        { x:0, y:0, value:3},
        { x:0, y:0, value:4},
        { x:0, y:0, value:5}
      ]
      grid.fillFromValues(values)
      expect(grid.valueAt(0,0)).toBe 4

    it 'Should interpolate from data', ->
      grid = new MeasureGrid(2)
      values = [
        { x:0, y:1, value:2},
        { x:1, y:0, value:2}
      ]
      grid.fillFromValues values
      expect(grid.valueAt(0,0)).toBe 2
      expect(grid.valueAt(1,1)).toBe 2

    it 'Should interpolate from outside', ->
      grid = new MeasureGrid(2)
      values = [
        { x:3, y:3, value:1},
      ]
      grid.fillFromValues values
      expect(grid.valueAt(1,1)).toBe 1
      expect(grid.valueAt(0,0)).toBe 1

    it 'Should interpolate from data with coefficients', ->
      grid = new MeasureGrid(4)
      values = [
        { x:0, y:0, value:1}
        { x:3, y:3, value:-1}
      ]
      grid.fillFromValues values, 4
      # diagonal
      expect(grid.valueAt(2,1)).toBe 0
      expect(grid.valueAt(1,2)).toBe 0
      # sample
      expect(grid.valueAt(0,2)).toBeLessThan 1

      grid.fillFromValues values, 2
      expect(grid.valueAt(0,2)).toBeLessThan 0.5

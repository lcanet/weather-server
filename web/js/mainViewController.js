angular.module('weatherDashboard').controller('mainViewController', function($scope, $http){
    $scope.searchQuery = '';
    $scope.showCompletions = false;

    $scope.mapParameters = {
        layer: 'temperature',
        marker: null,
        weather: true
    };

    $scope.toggleLayer = function(l) {
        if ($scope.mapParameters.layer === l) {
            $scope.mapParameters.layer = null;
        } else {
            $scope.mapParameters.layer = l;
        }
    };
    $scope.toggleWeatherLayer = function() {
        $scope.mapParameters.weather = !$scope.mapParameters.weather;
    };


    $scope.$watch('searchQuery', function(v){
        if (v) {
            $http.get('/stations/search?limit=6&q=' + encodeURIComponent(v)).success(function(res){
                $scope.searchResults = res;
                $scope.showCompletions = true;
            });
        }
    });

    $scope.selectEntry = function(s){
        $scope.showCompletions = false;
        $http.get('/station/' + s.code + '?format=simple').success(function(res){
            $scope.weather = res;
            $scope.mapParameters.marker = res;
        });
    };

    $scope.weatherIcon = function(w) {
        return 'wi-' + w.icon;
    };

    var DIRECTIONS = [ 'north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west' ];

    $scope.windIcon = function(w){
        for (var i = 0; i < DIRECTIONS.length; i++) {
            var min = 45*i - 45/2;
            var max = 45*i + 45/2;
            if (w.wind.direction >= min && w.wind.direction < max) return 'wi-wind-' + DIRECTIONS[i];
        }
        return 'wi-wind-north';
    };

    /**
     * because angular.filter date cannot use the timezone defined on the date. simply extract values from string
     * @param h
     */
    $scope.formatHour = function(h) {
        if (h) {
            var i1 = h.indexOf('T');
            var p = h.substring(i1+1).split(':');
            return p[0] + ':' + p[1];
        }
    };



});
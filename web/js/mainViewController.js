angular.module('weatherDashboard').controller('mainViewController', function($scope){
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


});
angular.module('weatherDashboard').controller('statsController', function($scope, $http, $mdBottomSheet) {

    var computeStepInfo = function(steps, total) {
        var stepsTotal = 0;
        for (var i = 0; i < steps.length; i++) {
            var item = steps[i];
            stepsTotal += item.count;
        }
        return {
            nb: stepsTotal,
            perc: 100 * stepsTotal / total
        };
    };

    $http.get('/stats').success(function(res){
        $scope.stats = res;

        $scope.statsByHour = {};

        // compute total
        var totalUpdates = 0;
        for (var i = 0; i < res.lastUpdates.length; i++) {
            var item = res.lastUpdates[i];
            totalUpdates += item.count;
        }

        if (res.lastUpdates.length > 2) {
            $scope.statsByHour.step1 = computeStepInfo([res.lastUpdates[0]], totalUpdates);
            $scope.statsByHour.step2 = computeStepInfo(res.lastUpdates.slice(0, 2), totalUpdates);
            $scope.statsByHour.step3 = computeStepInfo(res.lastUpdates.slice(0, 6), totalUpdates);
        }
    });
});
angular.module('weatherDashboard', ['ngRoute', 'ngMaterial']);

angular.module('weatherDashboard').run(['$timeout', function($timeout) {
    $timeout(function(){
        $('.preloader').fadeOut(300, function(){
            $('.main-content').show();
        });
    }, 50);
}]);
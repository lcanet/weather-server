angular.module('weatherDashboard').filter('toKmh', function(){
   return function(v) {
       if (v && angular.isNumber(v)) {
           return v  * 1.852;
       }
   };
});


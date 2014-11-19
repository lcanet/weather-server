angular.module('weatherDashboard').directive('mapView', function($rootScope){

    return {
        restrict: 'EA',
        replace: false,
        link: function(scope, elt, attrs) {
            L.Icon.Default.imagePath = 'images';

            // create a map in the "map" div, set the view to a given place and zoom
            var map = L.map(elt[0]).setView([51.505, -0.09], 5);

            // add an OpenStreetMap tile layer
            L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
                attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
            }).addTo(map);

            map.locate({setView: true});

            var overlay;
            var marker;

            scope.$watch('mapParameters.layer', function(l){
                if (overlay) {
                    map.removeLayer(overlay);
                }
                if (l) {
                    overlay = L.tileLayer('/map/' + l + '/{z}/{x}/{y}.png?d=' + new Date().getTime(), {
                        attribution: 'weather-api.lc6.net'
                    });
                    overlay.addTo(map);
                }
            });

            scope.$watch('mapParameters.marker', function(m){
                if (marker) {
                    map.removeLayer(marker);
                }
                if (m) {
                    var pos = L.latLng([m.lat, m.lon]);
                    marker = L.marker(pos, {
                        title: m.name
                    }).addTo(map);
                    map.panTo(pos);

                }

            });
        }
    }

});
angular.module('weatherDashboard').directive('mapView', function($rootScope, $http){
    var iconsCache = {};

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
            var weatherLayer = L.geoJson([], {
                onEachFeature: function (feature, layer) {
                    layer.bindPopup(feature.properties.city + ' ' + feature.properties.temperature + ' °C');
                },
                pointToLayer: function(feature, latLng) {
                    var iconName = feature.properties.icon;
                    var icon = iconsCache[iconName];
                    if (!icon) {
                        icon = L.divIcon({className: 'divicon wi wi-' +iconName, iconSize: [32, 32]});
                        iconsCache[iconName] = icon;
                    }
                    return L.marker(latLng, {icon: icon});
                }
            });
            weatherLayer.addTo(map);

            var refreshWeatherLayer = function() {
                weatherLayer.clearLayers();
                if (scope.mapParameters.weather) {
                    var zoom = map.getZoom();
                    if (zoom >= 7) {
                        var bounds = map.getBounds();
                        $http.get('/weather/geojson?minX=' + bounds.getSouth() +'&minY=' + bounds.getWest() +
                            '&maxX=' + bounds.getNorth() + '&maxY=' + bounds.getEast()).success(function(res){
                            weatherLayer.clearLayers();
                            weatherLayer.addData(res);
                        });
                    }
                }

            };
            refreshWeatherLayer();

            map.on('moveend', refreshWeatherLayer);
            map.on('zoomend', refreshWeatherLayer);

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

            scope.$watch('mapParameters.weather', function(){
                refreshWeatherLayer();
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
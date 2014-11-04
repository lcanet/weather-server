// indexes to create on mongo

db.stations.ensureIndex({code: 1});
db.stations.ensureIndex({point: '2dsphere'}, {spherical: true});
db.history.ensureIndex({icao:1, date: -1});

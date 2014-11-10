module.exports = function(grunt) {

    grunt.loadNpmTasks('grunt-contrib-coffee');
    grunt.loadNpmTasks('grunt-jasmine-node');

    // Project configuration.
    grunt.initConfig({
        coffee: {
            compile: {
                files: {
                    'src/metar.js': 'src/metar.coffee',
                    'src/poller.js': 'src/poller.coffee',
                    'src/backend.js': 'src/backend.coffee',
                    'src/server.js': 'src/server.coffee',
                    'src/transformers.js': 'src/transformers.coffee',
                    'src/responseTime.js': 'src/responseTime.coffee',
                    'src/iconifier.js': 'src/iconifier.coffee',
                    'src/dataExtractor.js': 'src/dataExtractor.coffee',
                    'src/tile.js': 'src/tile.coffee',
                    'src/grid.js': 'src/grid.coffee'

                }
            }
        },
        jasmine_node: {
            options: {
                forceExit: true,
                match: '.',
                matchall: false,
                extensions: 'js',
                specNameMatcher: 'spec',
                jUnit: {
                    report: true,
                    savePath : "./build/reports/jasmine/",
                    useDotNotation: true,
                    consolidate: true
                }
            },
            all: ['spec/']
        }
    });


    // Default task(s).
    grunt.registerTask('default', ['coffee']);
    grunt.registerTask('build', ['coffee', 'jasmine_node']);
    grunt.registerTask('test', ['coffee', 'jasmine_node']);

};
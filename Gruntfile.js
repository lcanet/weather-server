module.exports = function(grunt) {

    grunt.loadNpmTasks('grunt-contrib-coffee');

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
                    'src/iconifier.js': 'src/iconifier.coffee'

                }
            }
        }
    });


    // Default task(s).
    grunt.registerTask('default', ['coffee']);

};
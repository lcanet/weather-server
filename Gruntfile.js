module.exports = function(grunt) {

    // Load grunt tasks automatically
    require('load-grunt-tasks')(grunt);

    // Time how long tasks take. Can help when optimizing build times
    require('time-grunt')(grunt);

    // Configurable paths for the application
    var appConfig = {
        app: 'web',
        dist: 'webdist'
    };

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
                    savePath: "./build/reports/jasmine/",
                    useDotNotation: true,
                    consolidate: true
                }
            },
            all: ['spec/']
        },

        // Empties folders to start fresh
        clean: {
            dist: {
                files: [{
                    dot: true,
                    src: [
                        '.tmp',
                        'webdist/{,*/}*'
                    ]
                }]
            }
        },

        // Renames files for browser caching purposes
        filerev: {
            dist: {
                src: [
                    'webdist/js/{,*/}*.js',
                    'webdist/css/{,*/}*.css',
                    'webdist/fonts/*'
                ]
            }
        },

        // Reads HTML for usemin blocks to enable smart builds that automatically
        // concat, minify and revision files. Creates configurations in memory so
        // additional tasks can operate on them
        useminPrepare: {
            html: 'web/index.html',
            options: {
                dest: 'webdist',
                flow: {
                    html: {
                        steps: {
                            js: ['concat', 'uglifyjs'],
                            css: ['cssmin']
                        },
                        post: {}
                    }
                }
            }
        },

        // Performs rewrites based on filerev and the useminPrepare configuration
        usemin: {
            html: ['webdist/{,*/}*.html'],
            css: ['webdist/css/{,*/}*.css'],
            options: {
                assetsDirs: ['webdist','webdist/images']
            }
        },

        htmlmin: {
            dist: {
                options: {
                    collapseWhitespace: true,
                    conservativeCollapse: true,
                    collapseBooleanAttributes: true,
                    removeCommentsFromCDATA: true,
                    removeOptionalTags: true
                },
                files: [{
                    expand: true,
                    cwd: 'webdist',
                    src: ['*.html', 'views/{,*/}*.html'],
                    dest: 'webdist'
                }]
            }
        },

        // ng-annotate tries to make the code safe for minification automatically
        // by using the Angular long form for dependency injection.
        ngAnnotate: {
            dist: {
                files: [{
                    expand: true,
                    cwd: '.tmp/concat/js',
                    src: ['*.js', '!oldieshim.js'],
                    dest: '.tmp/concat/js'
                }]
            }
        },

        // Copies remaining files to places other tasks can use
        copy: {
            dist: {
                files: [
                    {
                        expand: true,
                        dot: true,
                        cwd: 'web',
                        dest: 'webdist',
                        src: [
                            '*.{ico,png,txt}',
                            '.htaccess',
                            '*.html',
                            'views/{,*/}*.html',
                            'images/{,*/}*.{webp}',
                            'fonts/{,*/}*.*'
                        ]
                    },
                    {
                        expand: true,
                        cwd: '.tmp/images',
                        dest: 'webdist/images',
                        src: ['generated/*']
                    }
                ]
            },
            styles: {
                expand: true,
                cwd: 'web/css',
                dest: '.tmp/css/',
                src: '{,*/}*.css'
            }
        }

    });

    // Default task(s).

    grunt.registerTask('serverbuild', ['coffee']);
    grunt.registerTask('servertest', ['coffee', 'jasmine_node']);

    grunt.registerTask('webbuild', [
        'clean:dist',
        'useminPrepare',
        'copy:styles',
        'concat',
        'ngAnnotate',
        'copy:dist',
        'cssmin',
        'uglify',
        'filerev',
        'usemin',
        'htmlmin'
    ]);

    grunt.registerTask('default', ['webbuild', 'serverbuild']);

};
module.exports = (grunt) ->
  'use strict'

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    # Task configuration
    clean:
      dist: 'dist'

    coffee:
      dist:
        expand: true
        cwd: 'public/assets/coffee'
        src: ['*.coffee']
        dest: 'public/assets/dist/js'
        ext: '.js'

    jshint:
      options:
        jshintrc: 'public/assets/coffee/.jshintrc'
      dist:
        src: [
          'public/assets/dist/js/*.js',
          '!public/assets/dist/js/*.min.js',
        ]

    uglify:
      options:
        mangle: true
        preserveComments: 'some'
      dist:
        expand: true
        cwd: 'public/assets/dist/js'
        src: ['**/*.js', '!**/*.min.js']
        dest: 'public/assets/dist/js'
        ext: '.min.js'

    csscomb:
      options:
        config: 'public/assets/less/.csscomb.json'
      dist:
        expand: true
        cwd: 'public/assets/dist/css'
        src: ['*.css', '!*.min.css']
        dest: 'public/assets/dist/css'

    cssmin:
      options:
        compatibility: 'ie8'
        keepSpecialComments: '*'
        advanced: false
      dist:
        expand: true
        cwd: 'public/assets/dist/css'
        src: ['*.css', '!*.min.css']
        dest: 'public/assets/dist/css'
        ext: '.min.css'

    less:
      dist:
        options:
          strictMath: true
          sourceMap: true
          outputSourceFiles: true
          sourceMapURL: '<%= pkg.name %>.css.map'
          sourceMapFilename: 'public/assets/dist/css/<%= pkg.name %>.css.map'
        expand: true
        cwd: 'public/assets/less'
        src: ['*.less']
        dest: 'public/assets/dist/css'
        ext: '.css'

    watch:
      coffee:
        files: 'public/assets/coffee/*.coffee'
        tasks: ['dist-js']
      less:
        files: 'public/assets/less/*.less'
        tasks: ['dist-css']

  require('load-grunt-tasks')(grunt, { scope: 'devDependencies' })
  require('time-grunt')(grunt)

  grunt.registerTask('lint-js', ['jshint:dist'])
  grunt.registerTask('dist-js', ['coffee:dist', 'uglify:dist'])
  grunt.registerTask('dist-css', ['less:dist', 'csscomb:dist', 'cssmin:dist'])
  grunt.registerTask('dist', ['clean', 'dist-js', 'dist-css'])

  # Default task
  grunt.registerTask('default', ['dist'])

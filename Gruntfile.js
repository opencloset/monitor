module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee: {
      compile: {
        options: {
          join: true
        },
        expand: true,
        cwd: 'public/assets/coffee',
        src: ['*.coffee'],
        dest: 'public/assets/coffee/js',
        ext: '.js'
      },
      compileBare: {
        options: {
          bare: true,
          join: true
        },
        expand: true,
        cwd: 'public/assets/coffee',
        src: ['*.coffee'],
        dest: 'public/assets/coffee/js',
        ext: '.js'
      }
    },
    uglify: {
      options: {
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' + 
          '<%= grunt.template.today("yyyy-mm-dd HH:MM:ss") %> */'
      },
      dist: {
        files: [{
          expand: true,
          cwd: 'public/assets/coffee/js',
          src: '*.js',
          dest: 'public/assets/js'
        }]
      }
    },
    watch: {
      js: {
        files: ['public/assets/coffee/js/*.js'],
        tasks: 'uglify'
      },
      sass: {
        files: ['public/assets/sass/screen.scss'],
        tasks: 'compass'
      },
      coffee: {
        files: ['public/assets/coffee/*.coffee'],
        tasks: 'coffee'
      }
    },
    compass: {
      dist: {
        options: {
          config: 'config.rb'
        }
      }
    }
  });
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-compass');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.registerTask('default', ['coffee:compileBare', 'uglify', 'compass']);
};

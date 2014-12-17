# Monitor #

Dashboard in waiting room

## Requirements ##

    $ npm install

    # install front-end pkg deps & build
    $ bower install
    $ grunt
    
    # use OpenCloset::Schema
    $ export PERL5LIB=/path/to/opencloset/lib:$PERL5LIB

## Run ##

    $ morbo -l 'http://*:5000' ./app.psgi    # http://localhost:5000

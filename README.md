# Monitor #

Dashboard in waiting room

## 요구사항 ##

    $ npm install

    # install front-end pkg deps & build
    $ bower install
    $ grunt
    
    # use OpenCloset::Schema
    $ export PERL5LIB=/path/to/opencloset/lib:$PERL5LIB

## 실행 ##

    $ morbo -l 'http://*:5000' ./app.psgi    # http://localhost:5000

## 환경변수 ##

- OPENCLOSET_WHITELIST

접속가능한 IP 목록입니다.

        # 192.168.0.* 이랑 182.73.2.57 을 허용
        $ export OPENCLOSET_WHITELIST=192.168.0.0/24,182.73.2.57

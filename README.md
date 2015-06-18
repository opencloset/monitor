# Monitor #

Dashboard in waiting room

## Version ##

v0.3.3

## 요구사항 ##

    $ sudo apt-get install redis-server
    $ npm install

    # install front-end pkg deps & build
    $ bower install

    $ cpanm --installdeps .
    $ cpanm --mirror https://cpan.theopencloset.net OpenCloset::Schema

## 실행 ##

    $ ln -s app.conf.sample monitor.conf
    $ morbo -l 'http://*:5000' ./app.psgi    # http://localhost:5000

## 환경변수 ##

- OPENCLOSET_WHITELIST

접속가능한 IP 목록입니다.

        # 192.168.0.* 이랑 182.73.2.57 을 허용
        $ export OPENCLOSET_WHITELIST=192.168.0.0/24,182.73.2.57

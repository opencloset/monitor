# Monitor #

[![Build Status](https://travis-ci.org/opencloset/monitor.svg?branch=v1.1.9)](https://travis-ci.org/opencloset/monitor)

Dashboard in waiting room

## Version ##

v1.1.9

## 요구사항 ##

    $ sudo apt-get install redis-server
    $ npm install

    # install front-end pkg deps & build
    $ bower install

    $ cpanm --installdeps .
    $ cpanm --mirror https://cpan.theopencloset.net OpenCloset::Schema

    $ sqlite3 db/monitor.db < db/init.sql

## 실행 ##

    $ grunt

    $ ln -s monitor.conf.sample monitor.conf
    $ MOJO_CONFIG=monitor.conf morbo -l 'http://*:5000' scripts/monitor    # http://localhost:5000

    $ OPENCLOSET_MONITOR_EMAIL=xx OPENCLOSET_MONITOR_PASSWORD=xx perl bin/suggestion_consumer.pl &

## 환경변수 ##

- `OPENCLOSET_WHITELIST`

접속가능한 IP 목록입니다.

        # 192.168.0.* 이랑 182.73.2.57 을 허용
        $ export OPENCLOSET_WHITELIST=192.168.0.0/24,182.73.2.57

- `OPENCLOSET_MONITOR_PORT`

defaults to `8002`

- `OPENCLOSET_DATABASE_DSN`
- `OPENCLOSET_DATABASE_NAME`
- `OPENCLOSET_DATABASE_USER`
- `OPENCLOSET_DATABASE_PASS`
- `OPENCLOSET_DATABASE_OPTS`
- `OPENCLOSET_MONITOR_EMAIL`

defaults to `monitor@theopencloset.net`

- `OPENCLOSET_MONITOR_PASSWORD`

## FAQ ##

### WRONGTYPE Operation against a key holding the wrong kind of value 오류 발생

실행 시 다음과 같은 오류가 발생할 수 있습니다.

```
[HGET opencloset:storage expiration] WRONGTYPE Operation against a key holding the wrong kind of value
```

이 경우 예전 버전의 `opencloset:storage` 키 유형 때문에 발생합니다.
다음 명령을 이용해서 해당 키를 제거한 다음 구동하면 정상 동작합니다.

```
$ redis-cli
127.0.0.1:6379> hget opencloset:storage expiration
(error) WRONGTYPE Operation against a key holding the wrong kind of value
127.0.0.1:6379> del opencloset:storage
(integer) 1
127.0.0.1:6379> hkeys opencloset:storage
(empty list or set)
$
```

### Build docker image ###

    $ docker build -t opencloset/monitor .
    $ docker build -f Dockerfile.minion -t opencloset/monitor/minion .

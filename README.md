# Monitor #

[![Build Status](https://travis-ci.org/opencloset/monitor.svg?branch=v1.1.20)](https://travis-ci.org/opencloset/monitor)

Dashboard in waiting room

## Version ##

v1.1.20

## 요구사항 ##

    $ sudo apt-get install redis-server
    $ npm install --global yarn
    $ yarn install

    $ yarn build    # for build frontend distribution
    $ yarn watch    # for development

    $ cpanm --mirror http://www.cpan.org \
        --mirror http://cpan.theopencloset.net \
        --installdeps .

    $ sqlite3 db/monitor.db < db/init.sql

### Install TTS mp3 files ###

- `public/tts/index`: `1번 탈의실로 입장해주세요`
  `1.mp3` ~ `15.mp3`
- `public/tts/room`: `1번 탈의실에 의류가 준비되었습니다`
  `1.mp3` ~ `15.mp3`

## 실행 ##

    $ ln -s monitor.conf.sample monitor.conf
    $ MOJO_CONFIG=monitor.conf morbo -l 'http://*:5000' scripts/monitor    # http://localhost:5000

## 환경변수 ##

- `OPENCLOSET_DATABASE_DSN`
- `OPENCLOSET_DATABASE_NAME`
- `OPENCLOSET_DATABASE_OPTS`
- `OPENCLOSET_DATABASE_PASS`
- `OPENCLOSET_DATABASE_USER`
- `OPENCLOSET_MONITOR_EMAIL`
  staff 서비스에 인증하기 위한 계정 이메일
- `OPENCLOSET_MONITOR_PASSWORD`
  staff 서비스에 인증하기 위한 계정 비밀번호
- `OPENCLOSET_NAVER_TTS_CLIENT_ID`
  https://www.ncloud.com/ 에서 추가한 애플리케이션(CSS)의 key
- `OPENCLOSET_NAVER_TTS_CLIENT_SECRET`
  https://www.ncloud.com/ 에서 추가한 애플리케이션(CSS)의 secret
- `OPENCLOSET_REDIS_URL` `redis://localhost:6379`
- `OPENCLOSET_STAFF_URL`
- `OPENCLOSET_WHITELIST`
  접속가능한 IP 목록
- `PORT`
  Listening port

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

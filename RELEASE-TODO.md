v1.1.21
v1.1.20

v1.1.19

    $ yarn build

v1.1.18

    $ closetpan OpenCloset::Common    # v0.1.9
    $ yarn install
    $ yarn build
    # install 1.mp3 ~ 15.mp3 to public/tts/index/
    # public/tts/index/1.mp3    # 1번 탈의실로 입장해주세요

v1.1.17

    # make sure "public/tts/room/1.mp3" ~ "public/tts/room/15.mp3"
    $ npm run build

v1.1.16

    $ NDENV_VERSION=v8.11.3 npm run build

v1.1.15

v1.1.14

    $ npm install
    $ npm run build
    $ grunt

v1.1.13

    $ cpanm WebService::Naver::TTS # v0.0.3

환경변수

- `OPENCLOSET_NAVER_TTS_CLIENT_ID`
- `OPENCLOSET_NAVER_TTS_CLIENT_SECRET`

를 새것으로 교체

v1.1.12

v1.1.11

v1.1.10

v1.1.9

    $ grunt
    $ closetpan OpenCloset::Common # v0.1.6

v1.1.8

    $ grunt

v1.1.7

    $ grunt

v1.1.6

    $ bower install
    $ grunt

v1.1.5

v1.1.4

    $ grunt

v1.1.3

v1.1.2

    $ closetpan OpenCloset::Size::Guess
    $ closetpan OpenCloset::Size::Guess::DB

v1.1.1

v1.1.0

    # add below to monitor.conf
    redis_url => $ENV{OPENCLOSET_REDIS_URL} || 'redis://localhost:6379',

    $ cpanm WebService::Naver::TTS    # v0.0.2

v1.0.5

v1.0.4

v1.0.3

    $ closetpan OpenCloset::Schema    # 0.054

v1.0.2

    $ grunt

v1.0.0

    # monitor.conf
    tts      => {
        naver => {
            client_id     => 'xxxxxxxxxxxxxxxxxxxx',
            client_secret => 'xxxxxxxxxx',
        }
    }

    # ubic.monitor.minion
    OPENCLOSET_NAVER_TTS_CLIENT_ID     => 'xxxxxxxxxxxxxxxxxxxx',
    OPENCLOSET_NAVER_TTS_CLIENT_SECRET => 'xxxxxxxxxx',

    $ cpanm WebService::Naver::TTS
    $ Digest::SHA1
    $ grunt

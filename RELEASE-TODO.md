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

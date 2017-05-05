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

#!/bin/bash

git send-email /labhome/chrism/net/r1/* --to=netdev@vger.kernel.org \
    --cc=jhs@mojatatu.com \
    --cc=lucasb@mojatatu.com \
    --cc=xiyou.wangcong@gmail.com \
    --cc=jiri@resnulli.us \
    --cc=davem@davemloft.net \
    --suppress-cc=all

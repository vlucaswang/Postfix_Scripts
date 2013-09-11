#!/bin/bash

QUEUETMP=/home/shell/queue.out
NUM=`/usr/sbin/postqueue -p|tail -1|gawk '{print $5 }'`

/usr/sbin/postqueue -p|tail -1 >$QUEUETMP

if ($NUM > 1000)
then
cat $QUEUETMP|mutt -s 'QUEUE WARNING!' admin@test.com
else
cat $QUEUETMP|mutt -s 'QUEUE INFO!' admin@test.com
fi

exit 0
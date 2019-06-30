#!/bin/sh

sleep 0.1

if ps ax | grep -v grep | grep jack > /dev/null
then
	if ps ax | grep -v grep | grep sclang > /dev/null
	then
		echo [3] ALL DONE
	else
		echo [2] STARTING SCLANG
		xvfb-run sclang supercollider.scd
	fi
else
	echo [1] PLUGGING IN JACK
	/usr/bin/jackd -R -P95 -t 1000 -dalsa -dhw:pisound -n3 -p128 -r48000 -s &
	sleep 0.1
	/usr/bin/scsynth -u 57110
    sleep 0.3

    echo [2] STARTING SCLANG
	xvfb-run sclang supercollider.scd
fi





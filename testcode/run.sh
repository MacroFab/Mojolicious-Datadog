#!/bin/sh

cd /var/mfab/apps/testcode
while :; do
  sudo -E -u www-data ./hypnotoad -f ./web
  echo restarting
  sleep 1
done

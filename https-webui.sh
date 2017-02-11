#!/bin/sh

SCRIPT_PATH="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
USE_SYSLOG='1'

if [ "$USE_SYSLOG" -eq '1' ]
then
  alias echo='logger -s -t HTTPS-WebUI'
fi

echo 'Mounting WebUI'
mount -o bind "$SCRIPT_PATH/www-pru" '/www'

echo 'Mounting httpd'
mount -o bind "$SCRIPT_PATH/httpd/httpd" '/usr/sbin/httpd'

echo 'Restarting httpd'
killall httpd
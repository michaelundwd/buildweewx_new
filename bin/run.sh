#!/usr/bin/env sh

HOME=/home/weewx
WEEWX_ROOT=$HOME/weewx-data
CONF_FILE=$WEEWX_ROOT/weewx.conf

echo "HOME=$HOME"
echo "using $CONF_FILE"
echo "weewx is in $WEEWX_ROOT"
echo "TZ=$TZ"

# add paths for
echo $PATH
PATH="$WEEWX_ROOT/bin:$PATH"
echo $PATH
PATH="$WEEWX_ROOT/bin/user:$PATH"
echo $PATH
PATH="$WEEWX_ROOT/scripts:$PATH"
echo $PATH

cd $WEEWX_ROOT

while true; do
  . /home/weewx/weewx-venv/bin/activate
  python3 $HOME/weewx/src/weewxd.py $CONF_FILE > /dev/stdout
  sleep 60
done

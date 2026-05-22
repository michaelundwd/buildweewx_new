#!/usr/bin/env sh

# ENV variables are defined in weewx container except
CONF_FILE=$WEEWX_ROOT/weewx.conf

echo "WeeWX Version:    $WEEWX_VERSION"
echo "Belchertown Skin: $BELCHERTOWN_VERSION"
echo "HOME:             $HOME"
echo "WEEWX_ROOT:       $WEEWX_ROOT"
echo "TimeZone:         $TZ"

cd $WEEWX_ROOT

. /home/weewx/weewx-venv/bin/activate
python3 $HOME/weewx/src/weewxd.py $CONF_FILE > /dev/stdout
exec "$@"

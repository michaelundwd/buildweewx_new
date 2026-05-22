# weewx_dev

This is the development version of a two stage dockerfile for weewx. This approach minimises the size of the final image/container.

The dockerfile is based on a fork from (https://github.com/tomdotorg/docker-weewx). My thanks to Tom.

The final lines in the file enable  a bash script to login in to the python virtual environment used by WeeWX, so that weectl is readily available.


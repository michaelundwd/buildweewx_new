# LORDSHIPWEATHER.UK docker image (weewx)
# Forked from https://github.com/tomdotorg/docker-weewx
# Two-stage dockerfile created for use by buildweex script
#     buildweewx stores user-defined ENV variables in version.txt
#     The build uses a local version of the github files
#     so that the ENV parameters can be edited into the local Dockerfile
#     Version (from version.txt line 1)
#     WeeWX version  (from version.txt line 2)
#     Belchertown  (from version.txt line 3)
#     The OS is debian:trixie; 
# This version last updated 04/06/2026 to use --build-arg

FROM python:trixie AS build-stage

  LABEL MAINTAINED_BY="Michael Underwood"
  LABEL FORKED_FROM="https://github.com/mitct02/docker-weewx by Tom Mitchell <tom@tom.org>"
  
  ENV HOME=/home/weewx
  ENV LANG=en_GB.UTF-8
  ENV TZ=Europe/London
  ENV WEEWX_ROOT=$HOME/weewx-data
  
  RUN apt-get update \
      && apt-get install --no-install-recommends -y \
          locales \
          tzdata \
      && rm -rf /var/lib/apt/lists/* \
      && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
      && locale-gen \
      && addgroup weewx \
      && useradd -m -g weewx weewx \
      && chown -R weewx:weewx /home/weewx \
      && chmod -R 755 /home/weewx

  USER weewx

  WORKDIR /home/weewx
    
  RUN python3 -m venv /home/weewx/weewx-venv \
      && chmod -R 755 /home/weewx

  RUN . /home/weewx/weewx-venv/bin/activate \
      && python3 -m pip install --no-cache-dir \
          configobj \
          CT3 \
          db-sqlite3 \
          ephem \
          numpy \
          paho-mqtt \
          pandas \
          Pillow \
          PyMySQL \
          pyserial \
          pyusb \
          requests \
          skyfield

  ARG w_val w_val
  ARG b_val v_val
  ENV WEEWX_VERSION=${w_val}
  ENV BELCHERTOWN_VERSION=${v_val}
  
  RUN mkdir -p /home/weewx/weewx \
      && wget https://github.com/weewx/weewx/archive/refs/tags/$WEEWX_VERSION.tar.gz \
      && tar -xzf $WEEWX_VERSION.tar.gz --strip-components=1 -C /home/weewx/weewx \
      && rm -f $WEEWX_VERSION.tar.gz 
  
  RUN . /home/weewx/weewx-venv/bin/activate \
      && python3 ~/weewx/src/weectl.py station create --no-prompt
  
  COPY conf-fragments/*.conf /home/weewx/tmp/conf-fragments/
  
  RUN mkdir -p /home/weewx/tmp \
      && mkdir -p /home/weewx/weewx-data \
      && cat /home/weewx/tmp/conf-fragments/* >> /home/weewx/weewx-data/weewx.conf

  ## Install extensions
  RUN cd /var/tmp \
    && . /home/weewx/weewx-venv/bin/activate \
    ## Belchertown-new extension
    && python3 ~/weewx/src/weectl.py extension install https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/$BELCHERTOWN_VERSION-new-belchertown.zip --yes \
    ## Interceptor Driver
    && python3 ~/weewx/src/weectl.py extension install https://github.com/matthewwall/weewx-interceptor/archive/master.zip --yes\
    ## MQTT extension
    && python3 ~/weewx/src/weectl.py extension install https://github.com/matthewwall/weewx-mqtt/archive/master.zip --yes \
    ## Skyfield extension
    // python3 ~/weewx/src/weectl.py extension install https://github.com/roe-dl/weewx-skyfield-almanac/archive/master.zip --yes \
    # Clean up Python bytecode from extensions
    && find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
    && find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true

  ## Create run-stage with reduced size

  FROM python:slim-trixie AS run-stage

  LABEL MAINTAINED_BY="Michael Underwood"
  LABEL FORKED_FROM="https://github.com/mitct02/docker-weewx by Tom Mitchell <tom@tom.org>"
  
  ENV HOME=/home/weewx
  ENV LANG=en_GB.UTF-8
  ENV TZ=Europe/London
  ENV WEEWX_ROOT=$HOME/weewx-data

  RUN apt-get update \
      && apt-get install --no-install-recommends -y \
          locales \
          tzdata \
          wget \
      && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
      && locale-gen \
      && addgroup weewx \
      && useradd -m -g weewx weewx \
      && chown -R weewx:weewx /home/weewx \
      && chmod -R 755 /home/weewx   
      
  COPY --from=build-stage /home/weewx /home/weewx
  
  ##  copy weewx-data to a folder that can be accessed from within container when running
  
  COPY --from=build-stage /home/weewx/weewx-data /home/weewx/weewx-build
  
  ##  These ENV variables are set near the end of Dockerfile, so that any changes minimises no of layers to be recreated in the image
  
  ARG b_val b_val
  ARG t_val t_val
  ARG v_val v_val
  ARG w_val w_val
  
  ENV VERSION=${v_val}
  ENV TAG=${t_val}
  ENV WEEWX_VERSION=${w_val}
  ENV BELCHERTOWN_VERSION=${b_val}
  
  USER weewx

  ## set up PATH for bin folder first
  ENV PATH="$HOME/weewx/bin:$PATH"
  
  ## modify .bashrc to include path to scripts and auto-activate weewx virtual environment on shell login
  RUN echo "export PATH=$PATH:$WEEWX_ROOT/scripts" >> ~/.bashrc \
    && echo " . ~/weewx-venv/bin/activate" >> ~/.bashrc
    
  ## start container using entrypoint located in the host where it can be edited directly
  ENTRYPOINT ["/home/weewx/weewx-data/scripts/entrypoint.sh"]
  WORKDIR $WEEWX_ROOT

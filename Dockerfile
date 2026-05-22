# LORDSHIPWEATHER.UK docker image (weewx)
# Forked from https://github.com/tomdotorg/docker-weewx
# for two-stage dockerfile
#     debian:trixie
#     WeeWX 5.2
#     Belchertown 1.6
# This version last updated 22/05/2026

FROM python:trixie AS build-stage

  LABEL MAINTAINED_BY="Michael Underwood"
  LABEL FORKED_FROM="https://github.com/mitct02/docker-weewx by Tom Mitchell <tom@tom.org>"
  ENV VERSION=weewx_52_b16:v2
  ENV TAG=v5.2.0
  ENV HOME=/home/weewx
  ENV WEEWX_ROOT=$HOME/weewx-data
  ENV WEEWX_VERSION=5.2.0
  ENV BELCHERTOWN_VERSION="v1.6"
  ENV TZ=Europe/London
  ENV LANG=en_GB.UTF-8
  
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

  RUN python3 -m venv /home/weewx/weewx-venv \
      && chmod -R 755 /home/weewx

  RUN . /home/weewx/weewx-venv/bin/activate \
      && python3 -m pip install --no-cache-dir \
          configobj \
          CT3 \
          db-sqlite3 \
          ephem \
          paho-mqtt \
          Pillow \
          PyMySQL \
          pyserial \
          pyusb \
          requests

  RUN git clone https://github.com/weewx/weewx.git ~/weewx \
      && cd ~/weewx \
      && git checkout $TAG \
      && rm -rf ~/weewx/.git \
      && rm -rf ~/weewx/docs ~/weewx/tests ~/weewx/.github ~/weewx/examples \
      && find /home/weewx/weewx-venv -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
      && find /home/weewx/weewx-venv -type f -name '*.pyc' -delete 2>/dev/null || true

  RUN . /home/weewx/weewx-venv/bin/activate \
      && python3 ~/weewx/src/weectl.py station create --no-prompt

  COPY conf-fragments/*.conf /home/weewx/tmp/conf-fragments/
  
  RUN mkdir -p /home/weewx/tmp \
      && mkdir -p /home/weewx/weewx-data \
      && cat /home/weewx/tmp/conf-fragments/* >> /home/weewx/weewx-data/weewx.conf

  ## Install extensions
  RUN cd /var/tmp \
    && . /home/weewx/weewx-venv/bin/activate \
    ## Belchertown extension - fixed version number for now - use ENV version when debugged
    ## Note that install can take place from .tar.gz and .zip files
    && wget -O belchertown-new.tar.gz https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/$BELCHERTOWN_VERSION.tar.gz \
    && python3 ~/weewx/src/weectl.py extension install -y belchertown-new.tar.gz \
    ## Interceptor Driver
    && wget -O weewx-interceptor.zip https://github.com/matthewwall/weewx-interceptor/archive/master.zip \
    && python3 ~/weewx/src/weectl.py extension install -y weewx-interceptor.zip \
    ## MQTT extension
    && wget -O weewx-mqtt.zip https://github.com/matthewwall/weewx-mqtt/archive/master.zip \
    && python3 ~/weewx/src/weectl.py extension install -y weewx-mqtt.zip \
    # Clean up Python bytecode from extensions
    && find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
    && find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true

  # create run-stage with reduced size

  FROM python:slim-trixie AS run-stage

  ENV VERSION=v2
  ENV TAG=v5.2.0
  ENV HOME=/home/weewx
  ENV WEEWX_ROOT=$HOME/weewx-data
  ENV WEEWX_VERSION=5.2.0
  ENV BELCHERTOWN_VERSION="v1.6"
  ENV TZ=Europe/London
  ENV LANG=en_GB.UTF-8

  RUN apt-get update \
      && apt-get install --no-install-recommends -y \
          locales \
          tzdata \
      && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
      && locale-gen \
      && addgroup weewx \
      && useradd -m -g weewx weewx \
      && chown -R weewx:weewx /home/weewx \
      && chmod -R 755 /home/weewx   
      
  COPY --from=build-stage /home/weewx /home/weewx
  
USER weewx

  # set up PATH for bin folder first
  ENV PATH="$HOME/weewx/bin:$PATH"
  
  # modify .bashrc to include path to scripts and auto-activate weewx virtual environment on shell login
  RUN echo "export PATH=$PATH:$WEEWX_ROOT/scripts" >> ~/.bashrc \
    && echo " . ~/weewx-venv/bin/activate" >> ~/.bashrc
    
  #start container using entrypoint located in the host where it can be edited directly
  ENTRYPOINT ["/home/weewx/weewx-data/scripts/entrypoint.sh"]
  WORKDIR $WEEWX_ROOT

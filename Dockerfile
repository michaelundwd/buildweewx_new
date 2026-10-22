# LORDSHIPWEATHER.UK docker image (weewx)
# Forked from https://github.com/tomdotorg/docker-weewx
# Two-stage dockerfile created for use by mju's buildweex script
#   buildweewx stores user-defined ENV variables in version.txt
#   that are transferred to  the image by means of ARG statements
#     ARG b_val new-belchertown skin version
#     ARG t_val tag eg weewx_522_b211
#     ARG v_val build version
#     ARG w_val weewx version
#     The OS is debian:trixie
#   IMPORTANT NOTE: this is a common build for both old and new belchertown versions
#   The build always includes v1.8 as that is the basis for live operation on zeropi

# Updated 20/09/2026 to ensure --build-arg values are available in runtime
# Updated 01/10/2026 as a common basis for old and new belchertown skins

# set global arguments

  ARG b_val
  ARG t_val
  ARG v_val
  ARG w_val
  
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

  ARG w_val
  ARG b_val
  ENV WEEWX_VERSION=${w_val}
  ENV BELCHERTOWN_VERSION=${b_val}
  
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
    && install_ext() { \
        echo "==> Installing extension: $1"; \
        out=$(python3 ~/weewx/src/weectl.py extension install "$1" --yes 2>&1) || { echo "$out"; echo "ERROR: weectl failed for $1" >&2; exit 1; }; \
        echo "$out"; \
        echo "$out" | grep -q "Finished installing extension" || { echo "ERROR: extension install did not complete: $1" >&2; exit 1; }; \
    } \
    ## Belchertown-old extension - v1.8 always installed as a basis for mju "old-belchertown"
    && install_ext https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/v1.8-new-belchertown.tar.gz --yes \
    ## Belchertown-new extension
    && install_ext https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/$BELCHERTOWN_VERSION.zip --yes \
    ## Interceptor Driver
    && install_ext https://github.com/matthewwall/weewx-interceptor/archive/master.zip --yes\
    ## MQTT extension
    && install_ext https://github.com/matthewwall/weewx-mqtt/archive/master.zip --yes \
    ## Skyfield extension
    && install_ext https://github.com/roe-dl/weewx-skyfield-almanac/archive/master.zip --yes \
    # Clean up Python bytecode from extensions
    && find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
    && find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true;

  ## Create run-stage with reduced size

  FROM python:slim-trixie AS run-stage

  LABEL MAINTAINED_BY="Michael Underwood"
  LABEL FORKED_FROM="https://github.com/mitct02/docker-weewx by Tom Mitchell <tom@tom.org>"
  
  ##  inherit global ARGS and set ENVs
  
  ARG b_val
  ARG t_val
  ARG v_val
  ARG w_val
  
  ENV VERSION=${v_val}
  ENV TAG=${t_val}
  ENV WEEWX_VERSION=${w_val}
  ENV BELCHERTOWN_VERSION=${b_val}
  
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
  
   USER weewx

  ## set up PATH for bin folder first
  ENV PATH="$HOME/weewx/bin:$PATH"
  
  ## modify .bashrc to include path to scripts and auto-activate weewx virtual environment on shell login
  RUN echo "export PATH=$PATH:$WEEWX_ROOT/scripts" >> ~/.bashrc \
    && echo " . ~/weewx-venv/bin/activate" >> ~/.bashrc
    
  ## start container using entrypoint located in the host where it can be edited directly
  ENTRYPOINT ["/home/weewx/weewx-data/scripts/entrypoint.sh"]
  WORKDIR $WEEWX_ROOT

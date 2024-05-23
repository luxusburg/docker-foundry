FROM steamcmd/steamcmd:alpine as base
LABEL maintainer="git@luxusburg.lu"

ARG DEBIAN_FRONTEND="noninteractive"
VOLUME ["/home/foundry/server_files", "/home/foundry/persistent_data"]

# Set environment variables
ENV USER foundry
ENV HOME /home/$USER
ENV TZ 'Europe/Berlin'
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install wine xvfb and cron
RUN apk add --no-cache wine xvfb xvfb-run doas tzdata musl musl-utils musl-locales libgcc

RUN echo 'export LC_ALL=$LC_ALL' >> /etc/profile.d/locale.sh && \
  sed -i 's|LANG=C.UTF-8|LANG=$LANG|' /etc/profile.d/locale.sh

RUN ln -s /usr/lib/libgcc_s.so.1 /usr/lib/wine/x86_64-unix/

# add new user
RUN addgroup -g ${PGUID:-1000} $USER && \
    adduser -D -G $USER -u ${PUID:-1000} $USER 

RUN echo "permit nopass $USER as root" > /etc/doas.conf

USER $USER
WORKDIR $HOME

# Copy batch files and give execute rights
ADD --chown=$USER:$USER ./files $HOME/scripts
RUN chmod +x $HOME/scripts/*.sh

ENTRYPOINT ["/bin/bash", "/home/foundry/scripts/entrypoint.sh"]
CMD ["/home/foundry/scripts/start.sh"]

FROM base as image-cron
USER root
# Setting up cron file for backup
ADD --chown=$USER:$USER ./files/foundry-cron /etc/cron.d/foundry-cron
RUN chmod 0644 /etc/cron.d/foundry-cron && \
    crontab /etc/cron.d/foundry-cron && \
    crond
USER $USER


FROM steamcmd/steamcmd:debian AS base
LABEL maintainer="git@luxusburg.lu"

ARG DEBIAN_FRONTEND="noninteractive"
VOLUME ["/home/foundry/server_files", "/home/foundry/persistent_data"]

# Set environment variables
ENV USER=foundry
ENV HOME=/home/$USER
ENV TZ='Europe/Berlin'
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install wine, xvfb, cron, and xauth (required for xvfb-run)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        jq \
        wine \
        xvfb \
        xauth \
        cron \
        tzdata \
        locales \
        sudo && \
    rm -rf /var/lib/apt/lists/*

RUN echo 'export LC_ALL=$LC_ALL' >> /etc/profile.d/locale.sh && \
    sed -i 's|LANG=C.UTF-8|LANG=$LANG|' /etc/profile.d/locale.sh

# add new user
RUN groupadd -g ${PGUID:-1000} $USER && \
    useradd -d $HOME -u ${PUID:-1000} -g $USER $USER && \
    mkdir -p $HOME && \
    chown $USER:$USER $HOME

RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER

USER $USER
WORKDIR $HOME

# Copy batch files and give execute rights
ADD --chown=$USER:$USER ./files $HOME/scripts
RUN chmod +x $HOME/scripts/*.sh

ENTRYPOINT ["/bin/bash", "/home/foundry/scripts/entrypoint.sh"]
CMD ["/home/foundry/scripts/start.sh"]

FROM base AS image-cron
USER root
# Setting up cron file for backup
ADD --chown=$USER:$USER ./files/foundry-cron /etc/cron.d/foundry-cron
RUN chmod 0644 /etc/cron.d/foundry-cron && \
    crontab /etc/cron.d/foundry-cron && \
    service cron start
USER $USER

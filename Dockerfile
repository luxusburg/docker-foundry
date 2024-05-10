FROM ubuntu:22.04 
LABEL maintainer="Git@Luxusburg"
VOLUME ["/mnt/foundry/server", "/mnt/foundry/persistentdata"]

ARG DEBIAN_FRONTEND="noninteractive"
RUN apt update -y && \
    apt-get upgrade -y && \
    apt-get install -y  apt-utils && \
    apt-get install -y  software-properties-common \
                        tzdata \
                        cron && \
    add-apt-repository multiverse && \
    dpkg --add-architecture i386 && \
    apt update -y && \
    apt-get upgrade -y 

# Setting up cron file for backup
ADD ./files/foundry-cron /etc/cron.d/foundry-cron
RUN chmod 0644 /etc/cron.d/foundry-cron

# Install steamcmd and create user
RUN useradd -m steam && cd /home/steam && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt purge steam steamcmd && \
    apt install -y gdebi-core  \
                   libgl1-mesa-glx:i386 \
                   wget && \
    apt install -y steam \
                   steamcmd && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd

# Install wine
RUN apt install -y wine \
                   winbind
RUN apt install -y xserver-xorg \
                   xvfb
RUN rm -rf /var/lib/apt/lists/* && \
    apt clean && \
    apt autoremove -y

# Copy batch files and give execute rights
COPY ./files/start.sh /start.sh
COPY ./files/app.cfg /home/steam/app.cfg
COPY ./files/env2cfg.sh /env2cfg.sh
COPY ./files/backup.sh /backup.sh
RUN chmod +x /start.sh /env2cfg.sh /backup.sh
CMD ["/start.sh"]
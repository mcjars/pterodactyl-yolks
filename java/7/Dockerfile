FROM        --platform=$TARGETOS/$TARGETARCH openjdk:7-jdk

LABEL       author="Robert Jansen" maintainer="rjansengd@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/mcjars/pterodactyl-yolks"
LABEL       org.opencontainers.image.licenses=MIT

RUN         echo "deb http://archive.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list \
						&& echo "deb http://archive.debian.org/debian-security/ jessie/updates main contrib non-free" >> /etc/apt/sources.list \
						&& echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/10-nocheckvalid

RUN         rm -rf /usr/bin/dd \
						&& rm -rf /usr/bin/fallocate \
						&& rm -rf /usr/bin/truncate \
						&& rm -rf /usr/bin/xfs_mkfile

RUN 		apt-get update -y --force-yes \
						&& apt-get install -y --force-yes jq unzip lsof ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 tzdata iproute2 libstdc++6 \
						&& useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]

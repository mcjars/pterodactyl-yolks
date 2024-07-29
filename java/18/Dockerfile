FROM        --platform=$TARGETOS/$TARGETARCH eclipse-temurin:18-jdk-jammy

LABEL       author="Robert Jansen" maintainer="rjansengd@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/mcjars/pterodactyl-yolks"
LABEL       org.opencontainers.image.licenses=MIT

RUN         rm -rf /usr/bin/dd \
						&& rm -rf /usr/bin/fallocate \
						&& rm -rf /usr/bin/truncate \
						&& rm -rf /usr/bin/xfs_mkfile

RUN         apt-get update -y \
						&& apt-get install -y curl

RUN         curl -sSL https://github.com/OpticFusion1/MCAntiMalware/releases/latest/download/MCAntiMalware.jar \
						-o /MCAntiMalware.jar

RUN 				apt-get install -y jq lsof ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 tzdata iproute2 libstdc++6 \
						&& useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]

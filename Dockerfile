ARG NODE_VERSION=12-alpine3.12

FROM node:$NODE_VERSION as theia
RUN apk add --no-cache make pkgconfig gcc g++ bash python3 libx11-dev libxkbfile-dev gnupg musl-dev openssl

ARG version=latest
WORKDIR /home/gleez

ADD $version.package.json ./package.json
ARG GITHUB_TOKEN

RUN yarn --pure-lockfile && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && \
    yarn theia download:plugins && \
    yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean

FROM node:$NODE_VERSION
WORKDIR /home/gleez

RUN apk add --update --no-cache sudo shadow htop git openssh bash libcap xz gpgme\
	bind-tools net-tools iputils coreutils curl wget nano vim tar ca-certificates \
	openssl protoc libprotoc libprotobuf protobuf-dev unzip bzip2 which python3 \
	nano jq icu krb5 zlib libsecret gnome-keyring desktop-file-utils xprop expect \
    mysql-client mariadb-client net-tools iputils openssh-client openssh-server \
    protoc libprotoc libprotobuf protobuf-dev inotify-tools \
	&& echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
 	&& echo http://nl.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories \
	&& echo http://nl.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
 	&& apk --no-cache add watchman py3-boto3 py3-boto aws-cli kubectl helm go \
 	&& rm -rf /var/cache/apk/*

# See: https://github.com/theia-ide/theia-apps/issues/34
RUN deluser node && \
	addgroup -g 1000 gleez && \
	adduser -D -S -u 1000 -G gleez -G wheel -h /home/gleez -s /bin/bash gleez && \
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers;

RUN chmod g+rw /home && \
	addgroup -g 10000 node && \
	adduser -u 10000 -G node -s /bin/sh -D node;

COPY --from=theia --chown=gleez:gleez /home/gleez /home/gleez
RUN npm install -g gen-http-proxy
RUN npm install -g @nestjs/cli

RUN mkdir -p /var/run/watchman/gleez-state \
    && chown -R gleez:gleez /var/run/watchman/gleez-state

RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    mkdir -p /home/gleez/.pub-cache/bin && \
    mkdir -p /usr/local/go-packages && \
    chown -R gleez:gleez /home/project && \
    chown -R gleez:gleez /home/gleez/.pub-cache/bin 

USER gleez

# Add our script
ADD ssl_theia.sh /home/gleez/ssl/

# Configure Theia
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/gleez/plugins  \
    # Configure user Go path
    GOPATH=/home/project \
	HOME=/home/gleez \
	USE_LOCAL_GIT=true
# ENV PATH=$PATH:$GOPATH/bin

## Setup misc
RUN git config --global user.email "hello@gleeztech.com" \
 && git config --global user.name "Gleez Technologies" \
 && touch ~/.sudo_as_admin_successful

# Set the parameters for the gen-http-proxy
ENV staticfolder /usr/local/lib/node_modules/gen-http-proxy/static 
ENV server :3080
ENV target localhost:3000
ENV secure 0 

EXPOSE 3080
# ENTRYPOINT [ "node", "/home/gleez/src-gen/backend/main.js", "/home/project", "--hostname=0.0.0.0" ]
ENTRYPOINT [ "/home/gleez/ssl/ssl_theia.sh" ]
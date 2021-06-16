ARG NODE_VERSION=12.19.1

FROM node:$NODE_VERSION-alpine3.12 as theia
RUN apk add --no-cache make pkgconfig gcc g++ python3 libx11-dev libxkbfile-dev gnupg

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

FROM node:$NODE_VERSION-alpine3.12
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
 	&& apk --no-cache add watchman py3-boto3 py3-boto aws-cli kubectl helm \
 	&& rm -rf /var/cache/apk/*

# See: https://github.com/theia-ide/theia-apps/issues/34
RUN deluser node && \
	addgroup -g 1000 gleez && \
	adduser -D -S -u 1000 -G gleez -G wheel -h /home/gleez -s /bin/bash gleez && \
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers;

RUN chmod g+rw /home && \
    # mkdir -p /home/project && \
    # mkdir -p /home/gleez/.pub-cache/bin && \
    # mkdir -p /usr/local/go && \
    # mkdir -p /usr/local/go-packages && \
    # chown -R gleez:gleez /home/project && \
    # chown -R gleez:gleez /home/gleez/.pub-cache/bin && \
    # chown -R gleez:gleez /usr/local/go && \
    # chown -R gleez:gleez /usr/local/go-packages && \
	addgroup -g 10000 node && \
	adduser -u 10000 -G node -s /bin/sh -D node;

COPY --from=theia --chown=gleez:gleez /home/gleez /home/gleez
RUN npm install -g @nestjs/cli

RUN mkdir -p /var/run/watchman/gleez-state \
    && chown -R gleez:gleez /var/run/watchman/gleez-state

## GO
ENV GO_VERSION=1.15 \
    GOOS=linux \
    GOARCH=amd64 \
    GOROOT=/usr/local/go \
    GOPATH=/usr/local/go-packages
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Install Go
RUN curl -fsSL https://storage.googleapis.com/golang/go$GO_VERSION.$GOOS-$GOARCH.tar.gz | tar -C /usr/local -xzv

# Install VS Code Go tools: https://github.com/Microsoft/vscode-go/blob/058eccf17f1b0eebd607581591828531d768b98e/src/goInstallTools.ts#L19-L45
RUN go get -u -v github.com/mdempsky/gocode && \
    go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs && \
    go get -u -v github.com/ramya-rao-a/go-outline && \
    go get -u -v github.com/acroca/go-symbols && \
    go get -u -v golang.org/x/tools/cmd/guru && \
    go get -u -v golang.org/x/tools/cmd/gorename && \
    go get -u -v github.com/fatih/gomodifytags && \
    go get -u -v github.com/haya14busa/goplay/cmd/goplay && \
    go get -u -v github.com/josharian/impl && \
    go get -u -v github.com/tylerb/gotype-live && \
    go get -u -v github.com/rogpeppe/godef && \
    go get -u -v github.com/zmb3/gogetdoc && \
    go get -u -v golang.org/x/tools/cmd/goimports && \
    go get -u -v github.com/sqs/goreturns && \
    go get -u -v winterdrache.de/goformat/goformat && \
    go get -u -v golang.org/x/lint/golint && \
    go get -u -v github.com/cweill/gotests/... && \
    go get -u -v github.com/alecthomas/gometalinter && \
    go get -u -v honnef.co/go/tools/... && \
    GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint && \
    go get -u -v github.com/mgechev/revive && \
    go get -u -v github.com/sourcegraph/go-langserver && \
    go get -u -v github.com/go-delve/delve/cmd/dlv && \
    go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct && \
    go get -u -v github.com/godoctor/godoctor

RUN go get -u -v -d github.com/stamblerre/gocode && \
    go build -o $GOPATH/bin/gocode-gomod github.com/stamblerre/gocode

ENV PATH=$PATH:$GOPATH/bin

RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    mkdir -p /home/gleez/.pub-cache/bin && \
    mkdir -p /usr/local/go && \
    mkdir -p /usr/local/go-packages && \
    chown -R gleez:gleez /home/project && \
    chown -R gleez:gleez /home/gleez/.pub-cache/bin && \
    chown -R gleez:gleez /usr/local/go && \
    chown -R gleez:gleez /usr/local/go-packages

USER gleez

# Configure Theia
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/gleez/plugins  \
    # Configure user Go path
    GOPATH=/home/project \
	HOME=/home/gleez \
	USE_LOCAL_GIT=true
ENV PATH=$PATH:$GOPATH/bin

## Setup misc
RUN git config --global user.email "hello@gleeztech.com" \
 && git config --global user.name "Gleez Technologies" \
 && touch ~/.sudo_as_admin_successful

EXPOSE 3000
ENTRYPOINT [ "node", "/home/gleez/src-gen/backend/main.js", "/home/project", "--hostname=0.0.0.0" ]
ARG NODE_VERSION=12.19.1

FROM node:$NODE_VERSION as theia

ARG GITHUB_TOKEN
ARG version=latest

WORKDIR /home/gleez

ADD $version.package.json ./package.json
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

COPY --from=theia /home/gleez /home/gleez

WORKDIR /home/gleez

# We need to add openssl to be able to create the certificates on demand
USER root

RUN apk update 2> /dev/null && apk add --update --no-cache sudo shadow htop git 
	nano jq net-tools iputils coreutils curl wget bash untar tar ca-certificates \
	openssl protoc libprotoc libprotobuf protobuf-dev

RUN npm install -g gen-http-proxy

# See: https://github.com/theia-ide/theia-apps/issues/34
RUN addgroup -g 1000 gleez && adduser -G gleez -u 1000 --disabled-password --gecos '' gleez && \
		adduser gleez sudo && \
		echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chmod g+rw /home && \
    mkdir -p /home/project && \
    mkdir -p /home/go && \
    mkdir -p /home/go-tools && \
    chown -R gleez:gleez /home/gleez && \
    chown -R gleez:gleez /home/project && \
    chown -R gleez:gleez /home/go && \
    chown -R gleez:gleez /home/go-tools;

USER gleez

ENV GO_VERSION=1.15 \
    GOOS=linux \
    GOARCH=amd64 \
    GOROOT=/home/go \
    GOPATH=/home/go-tools
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Install Go
RUN curl -fsSL https://storage.googleapis.com/golang/go$GO_VERSION.$GOOS-$GOARCH.tar.gz | tar -C /home -xzv

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

# Add our script
ADD ssl_theia.sh /home/gleez/ssl/

# Configure Theia
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/gleez/plugins  \
    # Configure user Go path
    GOPATH=/home/project
ENV PATH=$PATH:$GOPATH/bin

# Set the parameters for the gen-http-proxy
ENV staticfolder /usr/local/lib/node_modules/gen-http-proxy/static 
ENV server :$LISTEN_PORT
ENV target localhost:3000
ENV secure 0 

EXPOSE 3080

# Run theia and accept theia parameters
# ENTRYPOINT [ "node", "/home/gleez/src-gen/backend/main.js", "/home/project", "--hostname=0.0.0.0" ]
ENTRYPOINT [ "/home/gleez/ssl/ssl_theia.sh" ]

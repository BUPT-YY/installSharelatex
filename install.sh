#!/bin/bash


#使用 aliyun, 覆盖/etc/apt/sources.list之后apt-get update
#x86_64, ubuntu 18.04
sudo tee /etc/apt/sources.list <<-'EOF'
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
EOF

#arm64, ubuntu 20.04
#sudo tee /etc/apt/sources.list <<-'EOF'
#deb http://mirrors.aliyun.com/ubuntu-ports/ focal main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu-ports/ focal-updates main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu-ports/ focal-backports main restricted universe multiverse
#deb http://mirrors.aliyun.com/ubuntu-ports/ focal-security main restricted universe multiverse
#EOF

#安装docker和docker-compose
sudo apt-get update
sudo apt-get install -y docker.io net-tools openssh-server
sudo wget https://bootstrap.pypa.io/get-pip.py
sudo python3 get-pip.py
sudo pip3 install docker-compose

#aliyun 容器镜像加速
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://d9nabugg.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

#复制docker-compose.yml, sharelatex镜像改为yousiki/sharelatex:latest
sudo mkdir -p /home/test/ && cd /home/test/
sudo tee ./docker-compose.yml <<-'EOF'
version: '2.2'
services:
    sharelatex:
        restart: always
        image: yousiki/sharelatex:latest
        container_name: sharelatex
        depends_on:
            mongo:
                condition: service_healthy
            redis:
                condition: service_started
        ports:
            - 80:80
        links:
            - mongo
            - redis
        volumes:
            - ~/sharelatex_data:/var/lib/sharelatex
        environment:

            SHARELATEX_APP_NAME: Overleaf Community Edition

            SHARELATEX_MONGO_URL: mongodb://mongo/sharelatex

            # Same property, unfortunately with different names in
            # different locations
            SHARELATEX_REDIS_HOST: redis
            REDIS_HOST: redis

            ENABLED_LINKED_FILE_TYPES: 'url,project_file'

            # Enables Thumbnail generation using ImageMagick
            ENABLE_CONVERSIONS: 'true'

            # Disables email confirmation requirement
            EMAIL_CONFIRMATION_DISABLED: 'true'

            # temporary fix for LuaLaTex compiles
            # see https://github.com/overleaf/overleaf/issues/695
            TEXMFVAR: /var/lib/sharelatex/tmp/texmf-var
    mongo:
        restart: always
        image: mongo:4.0
        container_name: mongo
        expose:
            - 27017
        volumes:
            - ~/mongo_data:/data/db
        healthcheck:
            test: echo 'db.stats().ok' | mongo localhost:27017/test --quiet
            interval: 10s
            timeout: 10s
            retries: 5

    redis:
        restart: always
        image: redis:5
        container_name: redis
        expose:
            - 6379
        volumes:
            - ~/redis_data:/data
EOF

sudo docker-compose up -d

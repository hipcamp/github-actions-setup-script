#!/bin/bash

for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   
    case "$KEY" in
            RUNNERS)              RUNNERS=${VALUE} ;;
            GITHUB_URL)           GITHUB_URL=${VALUE} ;;
            TOKEN)                TOKEN=${VALUE} ;;
            LABELS)               LABELS=${VALUE} ;;
            *)   
    esac    
done

echo "Setting up $RUNNERS Runners"

## DOCKER Runner Setup
add-apt-repository ppa:git-core/ppa -y
curl -fsSL https://deb.nodesource.com/setup_14.x | -E bash -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get upgrade -y
apt-get install git -y
apt-get install -y nodejs
apt-get install -y python2
apt-get install -y libpq-dev
apt-get install -y uidmap
apt-get install -y dbus-user-session
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli containerd.io
apt-get install -y build-essential
apt-get install -y unzip
apt-get install -y rubygems
npm i -g yarn
apt-get upgrade -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest
chmod +x /usr/local/bin/ecs-cli
wget --quiet -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64
chmod +x /usr/local/bin/yq
apt-get install -y jq
wget --quiet https://github.com/mozilla/sops/releases/download/v3.7.1/sops_3.7.1_amd64.deb
dpkg -i sops_3.7.1_amd64.deb
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
loginctl enable-linger $(whoami)
groupadd docker
usermod -aG docker ${USER}
systemctl enable docker.service
systemctl enable containerd.service
# Docker System Prune Daily
(crontab -l 2>/dev/null; echo "@reboot /usr/bin/docker system prune -f --all") | crontab -
for i in $(seq 1 "$RUNNERS") 
do
    echo "Setting up new runner: $(hostname)-$i"
    mkdir actions-runner-$i && cd actions-runner-$i
    curl -o actions-runner-linux-x64-2.283.3.tar.gz -L https://github.com/actions/runner/releases/download/v2.283.3/actions-runner-linux-x64-2.283.3.tar.gz
    tar xzf ./actions-runner-linux-x64-2.283.3.tar.gz
    ./bin/installdependencies.sh
    RUNNER_ALLOW_RUNASROOT="true" ./config.sh --unattended --name $(hostname)-$i --url $GITHUB_URL --token $TOKEN --labels $LABELS
    echo "ImageOS=ubuntu20" >> .env
    ./svc.sh install
    ./svc.sh start
    cd ~
done

reboot
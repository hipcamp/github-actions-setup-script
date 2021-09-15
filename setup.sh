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

## ROOTLESS DOCKER Runner Setup
sudo add-apt-repository ppa:git-core/ppa -y
curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y
sudo apt install git -y
sudo apt install -y nodejs
sudo apt install -y uidmap
sudo apt install -y dbus-user-session
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo npm i -g yarn
sudo apt upgrade -y
dockerd-rootless-setuptool.sh install
# Add output to ~/.bashrc
echo '# Docker' >> ~/.bashrc
echo "export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock" >> ~/.bashrc
echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
# ===
. ~/.bashrc
sudo systemctl disable --now docker.service docker.socket
systemctl --user start docker
systemctl --user enable docker
sudo loginctl enable-linger $(whoami)
sudo groupadd docker
sudo usermod -aG docker ${USER}

for i in $(seq 1 "$RUNNERS") 
do
    echo "Setting up new runner: $(hostname)-$i"
    mkdir actions-runner-$i && cd actions-runner-$i
    curl -o actions-runner-linux-x64-2.281.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.281.1/actions-runner-linux-x64-2.281.1.tar.gz
    tar xzf ./actions-runner-linux-x64-2.281.1.tar.gz
    sudo ./bin/installdependencies.sh
    ./config.sh --unattended --name $(hostname)-$i --url $GITHUB_URL --token $TOKEN --labels $LABELS
    sudo ./svc.sh install
    sudo ./svc.sh start
    cd ~
done

sudo reboot
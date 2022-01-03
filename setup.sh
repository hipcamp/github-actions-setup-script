#!/bin/bash

for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   
    case "$KEY" in
            RUNNERS)              RUNNERS=${VALUE} ;;
            ORG)                  GITHUB_ORG=${VALUE} ;;
            LABELS)               LABELS=${VALUE} ;;
            *)   
    esac    
done

echo "Setting up $RUNNERS Runners"

## DOCKER Runner Setup
add-apt-repository ppa:git-core/ppa -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get update -y
apt-get upgrade -y
apt-get install -y nodejs
npm i -g yarn
apt-get install git -y
apt-get install -y python2
apt-get install -y libpq-dev
apt-get install -y uidmap
apt-get install -y dbus-user-session
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli containerd.io
apt-get install -y build-essential
apt-get install -y unzip
apt-get install -y rubygems
apt-get upgrade -y
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
# Docker System Prune
cat > cleanup.sh << EOF
#!/bin/bash

# Disable GHA Service
cd ~/actions-runner-1
./svc.sh stop
cd ~

if !(systemctl is-active --quiet docker.service)
then
    echo "Starting Docker Daemon"
    systemctl start docker
fi
echo "Run Cleanup"
docker system prune --all --force
docker volume rm \$(docker volume ls -qf dangling=true)

# Re-Enable GHA Service
cd ~/actions-runner-1
./svc.sh start
cd ~
EOF
chmod +x ./cleanup.sh
cat > /etc/systemd/system/gha-cleanup.service << EOF
[Unit]
Description=Runs GHA Cleanup at Shutdown and Reboot
DefaultDependencies=no
Before=shutdown.target reboot.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/root/cleanup.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable gha-cleanup.service
# (crontab -l 2>/dev/null; echo "@reboot sleep 60 && /usr/bin/docker system prune -f --all") | crontab -
for i in $(seq 1 "$RUNNERS") 
do
    echo "Setting up new runner: $(hostname)-$i"
    mkdir actions-runner-$i && cd actions-runner-$i
    curl -o actions-runner-linux-x64-2.283.3.tar.gz -L https://github.com/actions/runner/releases/download/v2.283.3/actions-runner-linux-x64-2.283.3.tar.gz
    tar xzf ./actions-runner-linux-x64-2.283.3.tar.gz
    ./bin/installdependencies.sh
    GITHUB_TOKEN=$(aws secretsmanager get-secret-value --secret-id GitHub/SELF_HOSTED_RUNNER_TOKEN | jq -r '.SecretString' | jq -r '.token')
    RUNNER_TOKEN=$(curl -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token | jq -r '.token')
    RUNNER_ALLOW_RUNASROOT="true" ./config.sh --unattended --name $(hostname)-$i --url "https://github.com/$GITHUB_ORG" --token $RUNNER_TOKEN --labels $LABELS
    echo "ImageOS=ubuntu20" >> .env
    ./svc.sh install $USER
    ./svc.sh start
    cd ~
done

shutdown

# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'getoptlong'

quay_username = ''
quay_password = ''

if ARGV.include?('up') || ARGV.include?('provision')
  opts = GetoptLong.new(
    [ '--quay-password', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--quay-username', GetoptLong::REQUIRED_ARGUMENT ]
  )

  opts.each do |opt, arg|
    case opt
      when '--quay-password'
        quay_password=arg
      when '--quay-username'
        quay_username=arg
    end
  end
end

SSH_KEY = File.expand_path(ENV.fetch('VAGRANT_SSH_KEY', '~/.ssh/id_rsa'))
if !File.exist?(SSH_KEY)
  error "ERROR: Please create an ssh key at the path #{SSH_KEY}"
  exit 1
end

if File.readlines(SSH_KEY).grep(/ENCRYPTED/).size > 0
  error "ERROR: GitHub SSH Key at #{SSH_KEY} contains a passphrase."
  error 'You need to generate a new key without a passphrase manually.'
  error 'See the vm documentation for more details.'
  error 'You can also override it\'s location with the environment variable VAGRANT_SSH_KEY'
  exit 1
end


$script = <<-SCRIPT
CURRENT_IP="$(ifconfig eth0 | grep "inet " | xargs | cut -d' ' -f2)"
# Update apt and get dependencies
sudo apt-get update > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -o=Dpkg::Use-Pty=0 -y unzip curl vim \
    apt-transport-https \
    ca-certificates \
    software-properties-common

pushd /tmp/ > /dev/null

echo "Fetching Nomad..."
NOMAD_VERSION=0.8.6
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip

echo "Fetching Consul..."
CONSUL_VERSION=1.2.3
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o consul.zip

echo "Fetching Levant..."
LEVANT_VERSION=0.2.2
curl -sL https://github.com/jrasell/levant/releases/download/${LEVANT_VERSION}/linux-amd64-levant -o levant

sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

# Set hostname's IP to made advertisement Just Work
#sudo sed -i -e "s/.*nomad.*/$(ip route get 1 | awk '{print $NF;exit}') nomad/" /etc/hosts

echo "Installing Docker..."
if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
    echo "Docker repository already installed; Skipping"
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update > /dev/null
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -o=Dpkg::Use-Pty=0 -y docker-ce

# Restart docker to make sure we get the latest version of the daemon if there is an upgrade
sudo service docker restart

echo "#{quay_password}" | sudo docker login -u="#{quay_username}" --password-stdin quay.io
sudo mkdir -p /root/.docker
sudo cp /home/vagrant/.docker/config.json /root/.docker/config.json
sudo chown -R vagrant:vagrant /home/vagrant/.docker
sudo chown -R root:root /root/.docker

# Make sure we can actually use docker as the vagrant user
sudo usermod -aG docker vagrant

echo "Installing Consul..."
unzip /tmp/consul.zip
sudo install consul /usr/bin/consul
sudo mkdir -p /etc/consul.d /var/lib/consul
(
cat <<-EOF
{
  "addresses": {
    "dns": "127.0.0.1"
  },
  "advertise_addr": "10.0.2.15",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "data_dir": "/var/lib/consul/",
  "datacenter": "dc1",
  "dns_config": {
    "only_passing": true,
    "allow_stale": true,
    "node_ttl": "60s",
    "service_ttl": {
      "*": "10s"
    }
  },
  "enable_syslog": true,
  "disable_remote_exec": true,
  "disable_update_check": true,
  "leave_on_terminate": true,
  "performance": {
    "raft_multiplier": 1
  },
  "ports": {
    "dns": 53
  },
  "recursors":[
    "8.8.8.8"
  ],
  "rejoin_after_leave": true,
  "skip_leave_on_interrupt": false,
  "bootstrap_expect": 1,
  "server": true,
  "ui": true
}
EOF
) | sudo tee /etc/consul.d/default.json > /dev/null

(
cat <<-EOF
  [Unit]
  Description=consul agent
  Requires=network-online.target
  After=network-online.target
  
  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/consul agent -config-file /etc/consul.d/default.json
  ExecReload=/bin/kill -HUP $MAINPID
  
  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/consul.service > /dev/null
sudo systemctl enable consul.service
sudo systemctl start consul

# systemctl daemon-reload && sudo systemctl restart consul.service
while [[ "$(curl -s -o /dev/null --connect-timeout 1 --max-time 1  -w ''%{http_code}'' localhost:8500/v1/status/leader)" != "200" ]]; do sleep 1; done

echo "Updating systemd-resolved"
(
cat <<-EOF
[Resolve]
DNS=127.0.0.1
Domains=~consul
EOF
) | sudo tee /etc/systemd/resolved.conf > /dev/null
sudo systemctl restart systemd-resolved.service

echo "Installing Nomad..."
unzip nomad.zip
sudo install nomad /usr/bin/nomad
sudo mkdir -p /var/lib/nomad
(
cat <<-EOF
{
  "bind_addr": "0.0.0.0",
  "data_dir": "/var/lib/nomad",
  "datacenter": "dc1",
  "disable_update_check": true,
  "enable_syslog": true,
  "leave_on_interrupt": true,
  "leave_on_terminate": true,
  "log_level": "DEBUG",
  "name": "",
  "addresses": {
    "http": "0.0.0.0",
    "rpc": "0.0.0.0",
    "serf": "0.0.0.0"
  },
  "advertise": {
    "http": "10.0.2.15:4646",
    "rpc": "10.0.2.15:4647",
    "serf": "10.0.2.15:4648"
  },
  "client": {
    "enabled": true,
    "network_interface": "eth0",
    "node_class": "nomad-server",
    "max_kill_timeout": "300s",
    "options": {
      "docker.auth.config": "/root/.docker/config.json",
      "docker.cleanup.image.delay": "1h",
      "driver.raw_exec.enable": true
    },
    "reserved": {
      "reserved_ports": "22,25,53,123,514,4646-4648,48484,49968,8200-8302,8400,8500,8600,8953"
    }
  },
  "consul": {
    "address": "127.0.0.1:8500",
    "client_auto_join": true,
    "client_service_name": "nomad-client",
    "server_auto_join": true,
    "server_service_name": "nomad"
  },
  "server": {
    "enabled": true,
    "bootstrap_expect": 1
  }
}
EOF
) | sudo tee /etc/nomad.d/default.json > /dev/null

(
cat <<-EOF
  [Unit]
  Description=nomad agent
  Requires=network-online.target
  After=network-online.target consul.service
  
  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/nomad agent -config /etc/nomad.d/default.json
  ExecReload=/bin/kill -HUP $MAINPID
  
  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/nomad.service > /dev/null
sudo systemctl enable nomad.service
sudo systemctl start nomad
while [[ "$(curl -s -o /dev/null --connect-timeout 1 --max-time 1  -w ''%{http_code}'' localhost:4646/v1/status/leader)" != "200" ]]; do sleep 1; done

# systemctl daemon-reload && sudo systemctl restart nomad.service

echo "Installing Levant..."
chmod +x levant
sudo install levant /usr/bin/levant

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "Installing $bin..."
  curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  sudo install /tmp/${bin} /usr/local/bin/${bin}
done

echo "Installing autocomplete..."
nomad -autocomplete-install

echo "Installing Dokku"
wget -nv -O - https://packagecloud.io/dokku/dokku-betafish/gpgkey | sudo apt-key add -
export SOURCE="https://packagecloud.io/dokku/dokku-betafish/ubuntu/"
export OS_ID="$(lsb_release -cs 2> /dev/null || echo "trusty")"
echo "utopicvividwilyxenialyakketyzestyartfulbionic" | grep -q "$OS_ID" || OS_ID="trusty"
echo "deb $SOURCE $OS_ID main" | sudo tee /etc/apt/sources.list.d/dokku-betafish.list > /dev/null

wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | sudo apt-key add -
export SOURCE="https://packagecloud.io/dokku/dokku/ubuntu/"
echo "deb $SOURCE $OS_ID main" | sudo tee /etc/apt/sources.list.d/dokku.list > /dev/null

sudo apt-get update > /dev/null

echo "dokku dokku/web_config boolean false"              | sudo debconf-set-selections
echo "dokku dokku/vhost_enable boolean true"             | sudo debconf-set-selections
echo "dokku dokku/hostname string dokku.me"              | sudo debconf-set-selections
echo "dokku dokku/skip_key_file boolean true"            | sudo debconf-set-selections
echo "dokku dokku/key_file string /root/.ssh/id_rsa.pub" | sudo debconf-set-selections
echo "dokku dokku/nginx_enable boolean false"            | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -o=Dpkg::Use-Pty=0 -y dokku
sudo dokku plugin:install-dependencies --core
sudo dokku plugin:install https://github.com/crisward/dokku-clone.git clone
sudo dokku plugin:install https://github.com/dokku/dokku-registry.git registry

sudo mkdir -p /home/dokku/.docker
sudo cp /home/vagrant/.docker/config.json /home/dokku/.docker/config.json
sudo chown -R vagrant:vagrant /home/vagrant/.docker
sudo chown -R dokku:dokku /home/dokku/.docker

sudo systemctl stop nginx.service
sudo systemctl disable nginx.service

echo "Pushing required jobs"
pushd /vagrant > /dev/null
make nomad-jobs

echo "Syncing plugin"
make sync

dokku clone:allow github.com
dokku apps:create python-sample
dokku registry:set python-sample server quay.io/
dokku registry:set python-sample image-repo dokku/python-sample
dokku registry:set python-sample username dokku
sudo apt-get install -qq -o=Dpkg::Use-Pty=0 -y asciinema

# dokku clone python-sample https://github.com/josegonzalez/python-sample.git

SCRIPT

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-18.04" # 18.04 LTS
  config.vm.hostname = "nomad"
  config.vm.provision "shell", inline: $script, privileged: false
  config.vm.provision "docker" # Just install it

  if File.exists?(SSH_KEY)
    ssh_key = File.read(SSH_KEY)
    config.vm.provision :shell, :inline => "echo 'Copying local GitHub SSH Key to VM for provisioning...' && mkdir -p /root/.ssh && echo '#{ssh_key}' > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa"
    config.vm.provision :shell, :inline => "echo 'Copying local GitHub SSH Key to VM for provisioning...' && mkdir -p /home/vagrant/.ssh && echo '#{ssh_key}' > /home/vagrant/.ssh/id_rsa && chmod 600 /home/vagrant/.ssh/id_rsa && chown -R vagrant:vagrant /home/vagrant/.ssh"
  else
    raise Vagrant::Errors::VagrantError, "\n\nERROR: GitHub SSH Key not found at ~/.ssh/id_rsa.\nYou can generate this key manually.\nYou can also override it with the environment variable VAGRANT_SSH_KEY\n\n"
  end

  config.vm.provision :shell do |shell|
    shell.inline = "echo 'Ensuring sudo commands have access to local SSH keys' && touch $1 && chmod 0440 $1 && echo $2 > $1"
    shell.args = %q{/etc/sudoers.d/root_ssh_agent "Defaults    env_keep += \"SSH_AUTH_SOCK\""}
  end

  # Expose the traefik api and ui to the host
  config.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
  config.vm.network "forwarded_port", guest: 81, host: 8081, auto_correct: true
  # Expose the hashi-ui api and ui to the host
  config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true
  # Expose the nomad api and ui to the host
  config.vm.network "forwarded_port", guest: 4646, host: 4646, auto_correct: true
  # Expose the consul api and ui to the host
  config.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true

  # Increase memory for Parallels Desktop
  config.vm.provider "parallels" do |p, o|
    p.memory = "1024"
  end

  # Increase memory for Virtualbox
  config.vm.provider "virtualbox" do |vb|
        vb.memory = "1024"
  end

  # Increase memory for VMware
  ["vmware_fusion", "vmware_workstation"].each do |p|
    config.vm.provider p do |v|
      v.vmx["memsize"] = "1024"
    end
  end
end

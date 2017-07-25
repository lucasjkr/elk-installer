#/bin/bash

# This script installs a relatively old ELK stack on Ubuntu Server 16.04 consisting of 
# the following:
#
# Kibana 4.5.4
# Logstash 2.3.4
# ElasticSearch 2.4.5
# Java8
#
# It's inspired by the instructions published by Digital Ocean here:
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elk-stack-on-ubuntu-14-04

function logStep(){
    echo $(date +%H:%M:%S) ": " $1 >> install.log
}

# Installing ELK on Ubuntu
## Need to open port 80 and 5044 to outside world
## Elasticsearch takes internal connections on 9200

# Variables that will need to be replace
# @internal_ip    = 127.0.0.1
# @external_ip    = 10.0.0.222
# @kibana_user    = kibana
# @kibana_pass    = kibana
# @fqdn           = elk.network.local
#
# Ports used
# SSH             = 22 /OpenSSH
# HTTP            = 80 /NginX
# HTTPS           = 443 /Nginx
# Kibana          = 5601
# Elastic         = 9200

## SET VARIABLES
NGINX_USER=kibana
NGINX_PASS=kibana
NGINX_HASH=PASSWD=openssl passwd -apr1 $NGINX_PASS
HOST_NAME="elk.logstash.local"
IP_ADDRESS=$(echo `ifconfig enp0s3 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)

touch install.log
echo $(date +%Y-%m-%d) " Installation log" >> install.log

# Optional (must execute commands as sudo each time, otherwise)
# su -s


## Update Hosts file
mv /etc/hosts /etc/hosts.old
cat <<EOT >> /etc/hosts
127.0.0.1       localhost
127.0.1.1       ubuntu
$IP_ADDRESS      $HOST_NAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

EOT

logStep "Updated /etc/hosts file"

### Add elastic.co's GPG key
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add repositories
sudo add-apt-repository -y ppa:webupd8team/java

echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | \
   tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" | \
   tee -a /etc/apt/sources.list
echo "deb http://packages.elastic.co/logstash/2.3/debian stable main" | \
   tee -a /etc/apt/sources.list

logStep "Added repositories"

# Update & Upgrade
apt-get update

logStep "apt-get update completed"

apt-get -y upgrade

logStep "apt-get upgrade completed"


## INSTALL HELPERS
apt-get -y install wget
logStep "Wget Installed"

apt-get -y install unzip
logStep "Unzip Installed"

apt-get -y install git
logStep "Git Installed"


# For silent installs: install Java 8 silently (otherwise, you'll need to manually accept the Oracle license)
echo debconf shared/accepted-oracle-license-v1-1 select true | \
  debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | \
  debconf-set-selections

## BEGIN INSTALLATION  
apt-get -y install oracle-java8-installer oracle-java8-set-default
logStep "Oracle Java 8 Installed"
  
# INSTALL APPLICATIONS
apt-get -y install elasticsearch 
logStep "ElasticSearch Installed"
  
apt-get -y install kibana
logStep "Kibana Installed"

apt-get -y install nginx
logStep "Nginx Installed"

apt-get -y install logstash
logStep "Logstash Installed"

apt-get -y install openssl
logStep "OpenSSL Installed"

#java -version

## CONFIGURE ELASTICSEARCH
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.old
sed -i 's/# network.host: 192.168.0.1/network.host: 127.0.0.1/g' /etc/elasticsearch/elasticsearch.yml
logStep "Updated elasticsearch.yml"

systemctl restart elasticsearch
systemctl daemon-reload
systemctl enable elasticsearch
logStep "Set elasticsearch to start with the system"

# CONFIGURE KIBANA:
## Replace default host (0.0.0.0) with local IP (127.0.0.1)
cp /opt/kibana/config/kibana.yml /opt/kibana/config/kibana.yml.old
sed -i 's/# server.host: \"0.0.0.0\"/server.host: \"127.0.0.1\"/g' /opt/kibana/config/kibana.yml
logStep "Updated kibana.yml"

systemctl daemon-reload
systemctl enable kibana
systemctl start kibana
logStep "Set kibana to start with the system"

echo $NGINX_USER":"$NGINX_HASH >> /etc/nginx/htpasswd.users
logStep "Created default nginx user and password to access Kibana interface"

# Make new nginx configuration file
# We'll need to change the server_name one day!
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old
logStep "Created backup nginx configuration file"

cat <<EOT >> /etc/nginx/sites-available/default
server {
    listen 80;

    server_name $HOST_NAME
    
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;        
    }
}
EOT
logStep "Created new nginx configuration file"

# Could run this to see that the new file is OK
# nginx -t

systemctl restart nginx
logStep "Restarted Nginx"

## Install OpenSSL
cd /etc/ssl/
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout logstash-forwarder.key -out logstash-forwarder.crt -subj /CN=$HOST_NAME
logStep "Generated SSL certificate for logstash-forwarder service"


## CREATE CONFIGURATION FILES FOR LOGSTASH
## After each file is created, we should expect to see "Configuration OK"

## Create LOGSTASH CONFIGURATION
cat <<EOT >> /etc/logstash/conf.d/02-beats-input.conf
input {
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/ssl/logstash-forwarder.crt"
    ssl_key => "/etc/ssl/logstash-forwarder.key"
  }
}
EOT
/opt/logstash/bin/logstash --configtest -f /etc/logstash/conf.d/02-beats-input.conf
logStep "Created and verified logstash beats input"


## CREATE SYSLOG FILTER
cat <<EOT >> /etc/logstash/conf.d/10-syslog-filter.conf
filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
      add_field => [ "received_at", "%{@timestamp}" ]
      add_field => [ "received_from", "%{host}" ]
    }
    syslog_pri { }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}
EOT
/opt/logstash/bin/logstash --configtest -f /etc/logstash/conf.d/10-syslog-filter.conf
logStep "Created and verified logstash syslog filter"

## CREATE ELASTIC SEARCH CONFIG
cat <<EOT >> /etc/logstash/conf.d/30-elasticsearch-output.conf
output {
  elasticsearch {
    hosts => ["localhost:9200"]
    sniffing => true
    manage_template => false
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
EOT
/opt/logstash/bin/logstash --configtest -f /etc/logstash/conf.d/30-elasticsearch-output.conf
logStep "Created and verified logstash's elasticsearch output"q

## RESTART & ENABLE LOGSTASH
systemctl restart logstash
systemctl enable logstash
logStep "Restarted logstash service"

## Load Kibana Dashboards
cd ~
curl -L -O https://download.elastic.co/beats/dashboards/beats-dashboards-1.2.2.zip
unzip beats-dashboards-*.zip
cd beats-dashboards-*
./load.sh
logStep "Loaded Kibana dashboards"

## Load Filebeat Index Template
cd ~
curl -O https://gist.githubusercontent.com/thisismitch/3429023e8438cc25b86c/raw/d8c479e2a1adcea8b1fe86570e42abab0f10f364/filebeat-index-template.json
curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json
logStep "Filebeat Template installed."
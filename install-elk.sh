#/bin/bash

###########################################################
#                                                         #
# System specific variables                               #
#                                                         #
###########################################################
### These don't work yet - the intention is to personalize
### the installation, so this is a TODO item!
# NGINX_USER=kibana
# NGINX_PASS=kibana
# NGINX_HASH=PASSWD=openssl passwd -apr1 $NGINX_PASS
# HOST_NAME="s01.elasticstack.local"
# LOCAL_IP=$(echo `ifconfig enp0s3 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)
 
###########################################################
#                                                         #
# Setup for installation                                  #
#                                                         #
###########################################################
### Update Repositories and install dependencies
### Some of these might already be installed on your system
### But it doesn't hurt to make sure

apt-get update

### Optional and recommended, upgrade all packages:
apt-get update
apt-get dist-upprade

apt-get -y install wget
apt-get -y install unzip
apt-get -y install git
apt-get -y install apt-transport-https

###########################################################
#                                                         #
# Oracle Java8 Installation                               #
#                                                         #
###########################################################

add-apt-repository -y ppa:webupd8team/java
apt-get update

### Uncomment the next four lines to not be prompted about
### accepting Oracles license agreement:
echo debconf shared/accepted-oracle-license-v1-1 select true | \
  debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | \
  debconf-set-selections
apt-get -y install oracle-java8-installer oracle-java8-set-default

### TODO check java status with
### java -version

###########################################################
#                                                         #
# Prepare for elasticstack installation                   #
#                                                         #
###########################################################
### Add elastic GPG key
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | \
  apt-key add -

# Add elasticsearch repository
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | \
  tee -a /etc/apt/sources.list.d/elastic-5.x.list
 
apt-get update

### TODO: check fingerprint should verify as
### 4609 5ACC 8548 582C 1A26 99A9 D27D 666C D88E 42B4

###########################################################
#                                                         #
# ElasticSearch installation                              #
#                                                         #
###########################################################
apt-get -y install elasticsearch

### BACKUP AND UPDATE elasticsearch.yml
cp /etc/elasticsearch/elasticsearch.yml \
  /etc/elasticsearch/elasticsearch.yml.original

sed -i 's/#network.host: 192.168.0.1/network.host: localhost/g' \
  /etc/elasticsearch/elasticsearch.yml
sed -i 's/#cluster.name: my-application/cluster.name: elasticstack/g' \
  /etc/elasticsearch/elasticsearch.yml

# Optional: reduce elastic's memory footprint
cp /etc/elasticsearch/jvm.options \
  /etc/elasticsearch/jvm.options.original
sed -i 's/-Xms2g/-Xms512m/g' \
  /etc/elasticsearch/jvm.options
sed -i 's/-Xmx2g/-Xms512m/g' \
  /etc/elasticsearch/jvm.options

update-rc.d elasticsearch defaults 95 10
service elasticsearch stop 

###########################################################
#                                                         #
# Kibana installation                                     #
#                                                         #
###########################################################
apt-get -y install kibana
update-rc.d kibana defaults 95 10
service kibana stop

###########################################################
#                                                         #
# Nginx (reverse proxy) installation                      #
#                                                         #
###########################################################
apt-get -y install nginx

mv /etc/nginx/sites-available/default \
  /etc/nginx/sites-available/default.original

##TODO: insert real FQDN or IP Address into server name
cat <<EOT >> /etc/nginx/sites-available/default
server {
    listen 80;
 
    server_name 10.0.0.127;
 
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
service nginx stop

###########################################################
#                                                         #
# Logstash installation                                   #
#                                                         #
###########################################################
apt-get -y install logstash
service logstash stop
 
# at this point, you can test your logstash installation by issuing the following commands:
# /usr/share/logstash/bin/logstash -e 'input { stdin { } } output { stdout {} }'
# (wait for prompt, then enter: 'hello world')
# After you see the result, you can exit logstash by hitting ctrl-d)

###########################################################
#                                                         #
# X-pack for Elasticsearch                                #
#                                                         #
###########################################################
/usr/share/elasticsearch/bin/elasticsearch-plugin install x-pack --batch

###########################################################
#                                                         #
# X-pack for Kibana                                       #
#                                                         #
###########################################################
/usr/share/kibana/bin/kibana-plugin install x-pack

###########################################################
#                                                         #
# X-pack for Logstash                                     #
#                                                         #
###########################################################
/usr/share/logstash/bin/logstash-plugin install x-pack

###########################################################
#                                                         #
# Start Elasticstack Services                             #
#                                                         #
###########################################################
service nginx start
service elasticsearch start
service kibana start
service nginx start
service logstash start

# this can take a minute

###########################################################
#                                                         #
# Default login info                                      #
#                                                         #
###########################################################
# Point browser to elasticstack server address:
# http://elasticstack.local
#
# Default username: elastic
# Default password: changeme
#
#
##
###########################################################
#                                                         #
# Application directories                                 #
#                                                         #
###########################################################
# /usr/share/elasticsearch
# /usr/share/kibana
# /usr/share/logstash
#
##
###########################################################
#                                                         #
# Sources                                                 #
#                                                         #
###########################################################
#
# Elasticstack installation overview:
# https://www.elastic.co/guide/en/elastic-stack/current/installing-elastic-stack.html
#
# Elastic Search installation:
# https://www.elastic.co/guide/en/elasticsearch/reference/5.5/install-elasticsearch.html
#
# Kibana Installation
# https://www.elastic.co/guide/en/kibana/5.5/setup.html
#
# Logstash installation:
# https://www.elastic.co/guide/en/logstash/5.5/installing-logstash.html
#
# Testing Logstash:
# https://www.elastic.co/guide/en/logstash/5.5/first-event.html
#
# X-Pack for Elasticsearch
# https://www.elastic.co/guide/en/elasticsearch/reference/5.5/installing-xpack-es.html
#
# X-Pack for Kibana
# https://www.elastic.co/guide/en/kibana/5.5/installing-xpack-kb.html
#
# X-Pack for Logstash
# https://www.elastic.co/guide/en/logstash/5.5/installing-logstash.html
#
#
############################################################
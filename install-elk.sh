#/bin/bash

###########################################################
#                                                         #
# System specific variables                               #
#                                                         #
###########################################################
# TODO: Validation!
# Have each item entered twice to insure the user entered the correct data

echo "Enter your servers hostname (i.e. host.example.com):"
read ELKHOST

echo "Enter admin name"
read ADMINUSER

echo "Enter admin password"
read ADMINPASS

# Create .htpasswd file to authenticate against in later steps
mkdir -p /etc/nginx/ 
echo -n "$ADMINUSER:" >> /etc/nginx/nginx.users
openssl passwd -apr1 $ADMINPASS >> /etc/nginx/nginx.users

# TODO: Ask for Elasticsearch Memory allocations

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

# For installing software
apt-get -y install software-properties-common apt-transport-https

# For retrieving remote files
apt-get -y install wget zip unzip git

# SSL capabilities (SSL key for Logstash, etc)
apt-get -y install openssl

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
/bin/systemctl daemon-reload
/bin/systemctl enable elasticsearch.service

### BACKUP AND UPDATE elasticsearch.yml
cp /etc/elasticsearch/elasticsearch.yml \
  /etc/elasticsearch/elasticsearch.yml.original

sed -i 's/#network.host: 192.168.0.1/network.host: localhost/g' \
  /etc/elasticsearch/elasticsearch.yml
sed -i 's/#cluster.name: my-application/cluster.name: elasticstack/g' \
  /etc/elasticsearch/elasticsearch.yml
sed -i 's/#node.name: node-1/#node.name: node-1\nnode.name: master/g' \
  /etc/elasticsearch/elasticsearch.yml


# IMPORTANT: SET ELASTICSEARCH LOG AND DATA DIRECTORIES
mkdir -p /data/elastic/data
mkdir -p /data/elastic/logs

chown elasticsearch /data/elastic/data
chgrp elasticsearch /data/elastic/data
chmod 770 /data/elastic/data

chgrp elasticsearch /data/elastic/logs
chgrp elasticsearch /data/elastic/logs
chmod 770 /data/elastic/logs

sed -i 's/#path.data: \/path\/to\/data/\npath.data: \/data\/elastic\/data/g' \
  /etc/elasticsearch/elasticsearch.yml
sed -i 's/#path.data: \/path\/to\/logs/\npath.data: \/data\/elastic\/logs/g' \
  /etc/elasticsearch/elasticsearch.yml

# Optional: reduce elastic's memory footprint
# Per elastic's documentation, both min and max should be the same size
cp /etc/elasticsearch/jvm.options \
  /etc/elasticsearch/jvm.options.original
sed -i 's/-Xms2g/-Xms300m/g' \
  /etc/elasticsearch/jvm.options
sed -i 's/-Xmx2g/-Xmx300m/g' \
  /etc/elasticsearch/jvm.options

###########################################################
#                                                         #
# Kibana installation                                     #
#                                                         #
###########################################################
apt-get -y install kibana
/bin/systemctl daemon-reload
/bin/systemctl enable kibana.service

cp /etc/kibana/kibana.yml \
  /etc/kibana/kibana.yml.original
  
sed -i 's/#kibana.index: ".kibana"/#kibana.index: ".kibana"\nkibana.index: ".kibana"/g' \
  /etc/kibana/kibana.yml

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
 
    server_name 99.99.99.99;
 
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/nginx.users;
 
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

# CHANGE server_name variable to the one the user chose at the beginning of the script
sed -i "s|99.99.99.99|$ELKHOST|g" \
  /etc/nginx/sites-available/default
  
###########################################################
#                                                         #
# Logstash installation                                   #
#                                                         #
###########################################################
apt-get -y install logstash
/bin/systemctl daemon-reload
/bin/systemctl enable logstash.service

#add the Logstash Beats inputplugin
/usr/share/logstash/bin/logstash-plugin install logstash-input-beats

#add the Logstash Elasticsearch output plugin
/usr/share/logstash/bin/logstash-plugin install logstash-output-elasticsearch

# at this point, you can test your logstash installation by issuing the following commands:
# /usr/share/logstash/bin/logstash -e 'input { stdin { } } output { stdout {} }'
# (wait for prompt, then enter: 'hello world')
# After you see the result, you can exit logstash by hitting ctrl-d)

###########################################################
#                                                         #
# Start Elasticstack Services                             #
#                                                         #
###########################################################
/bin/systemctl daemon-reload
/bin/systemctl start elasticsearch.service
/bin/systemctl start kibana.service
/bin/systemctl start logstash.service
service nginx restart

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
# Logstash Beats plug-in
# https://www.elastic.co/guide/en/beats/libbeat/5.5/logstash-installation.html
#
# Testing Logstash:
# https://www.elastic.co/guide/en/logstash/5.5/first-event.html
#
# TODO: Install logstash plugins
#
# Installing Logstash Plugins
# https://www.elastic.co/guide/en/logstash/current/working-with-plugins.html
#
# List all plugins:
# /usr/share/logstash/bin/logstash-plugin list
############################################################
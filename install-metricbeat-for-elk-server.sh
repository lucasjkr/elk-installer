#/bin/bash

# Metricbeat Client
# This script installs metricbeat directly on the ES instance;
# I'll make a second script for other clients to transmit metrics through logstash
 
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list
apt-get update

sudo apt-get install metricbeat
sudo update-rc.d metricbeat defaults 95 10
service metricbeat start

# Load dashboards into Kibana
/usr/share/metricbeat/scripts/import_dashboards
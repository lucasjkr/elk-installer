This installs Elastic Stack 5.5, according to Elastic's official instructions,
found here:

https://www.elastic.co/guide/en/elastic-stack/5.5/installing-elastic-stack.html

It installs the following:

    Elasticsearch         5.5
    Kibana                5.5
    Logstash              5.5
    
As well as the latest versions of `Oracle Java8` and `Nginx` (the later used as a reverse proxy server with basic authentication)

**INSTRUCTIONS**
The goal is to install and configure the stack with a single command on a single server

    install-elastic-stack.sh    

Alternatively, the installer has been broken out into discrete scripts for each individual package. If use those, they should be (but probably don't need to be) run in the following order:

**NOTES:**
This set of scripts is being tested on:

    Ubuntu 16.04 Server ISO installed in VirtualBox
    Ubuntu Server 16.04 LTS as installed in Linode
    
May require alterations to run on other distributions. 
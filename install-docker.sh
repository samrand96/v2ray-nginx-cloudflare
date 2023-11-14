#!/bin/bash
set -e
sudo su -c "bash <(wget -qO- https://get.docker.com)" root
apt install -y docker-compose
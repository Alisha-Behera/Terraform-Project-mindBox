#!/bin/bash

sudo apt-get update
sudo apt-get install apache2 -y

git clone https://github.com/amolshete/card-website.git

cd /var/www/html
rm index.html
cp -rf card-website/*  /var/www/html
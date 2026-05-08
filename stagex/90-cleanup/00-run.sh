#!/bin/bash -e

echo -e "\e[32m### Copy pwnagotchi config ###\e[0m"
cp /opt/pwnagotchi/defaults.toml /etc/pwnagotchi/config.toml

echo -e "\e[32m### Clean up the system ###\e[0m"
apt-get clean
apt autoremove

#!/bin/bash

# Refer to https://docs.docker.com/engine/install/debian/ to verify script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo bash get-docker.sh

# Define function to set the user permissions
setUser() {
  sudo groupadd docker
  sudo usermod -aG docker $USER
  newgrp docker
}

# Clean up downloaded file
rm get-docker.sh

# Ask the user if they would like to enable the current user with access to the docker user group

echo "Do you wish to enable non-sudo user access to docker user group?"
select yn in "Yes" "No"; do
  case $yn in
  Yes)
    setUser
    break
    ;;
  No) exit ;;
  esac
done

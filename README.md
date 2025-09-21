# linux-container-setup
random scripts to help after provisioning lxc containers on proxmox

## Initial Installations
Install inital configuration below as root - this script will allow you to set up a user to run all the following commands
```
/bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/JoshKoiro/linux-container-setup/main/initialconfig.sh)"
```
Install homebrew and gum to prepare for other installation and configuration scripts. This has to be done separate because homebrew is annoying with the $PATH but at least you don't have to build stuff from source.
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/homebrew-gum.sh)"
```

**Make sure to run `source ~/.bashrc` after the previous script so homebrew is added to the $PATH**

## Environment
Run this code to set up the environment goodies!
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/env-setup.sh)"
```
## Dotfiles and Github SSH
Now time to download the dot files and get stuff looking pretty! - Use this process as a template for you to create your own dotfiles

If I just want to download and update using `git pull origin main` then I'll use this:
```
git clone https://github.com/JoshKoiro/dotfiles.git
```
If you want to update and push back to the repository using the best practices for github then use this:

```
git clone git@github.com:JoshKoiro/dotfiles.git
```
In order to use an ssh connection to clone the dot files, you first need to set up your github ssh keys.

First, run this script from my github-ssh repository:
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/github-ssh/main/config.sh)"
```

During execution, you will be asked to provide a personal access token for github. You can create one here: https://github.com/settings/tokens

Follow the instructions and then once complete, you can clone the above repository.

## Docker
Run this code to setup docker
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/docker.sh)"
```
## SSH Keys
Run this code to set up ssh keys
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/ssh-key-setup.sh setup)"
```
## Batch SSH Keys
You can batch ssh key creation using this script
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/batch-ssh-key-setup.sh)"
```
## Development Environment
```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/devconfig.sh)"
```

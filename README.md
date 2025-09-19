# linux-container-setup
random scripts to help in provisioning lxc containers on proxmox - until I figure out terraform...

Install inital configuration as root - this script will allow you to set up a user

```
/bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/JoshKoiro/linux-container-setup/main/initialconfig.sh)"
```

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/homebrew-gum.sh)"
```

**Make sure to run `source ~/.bashrc` after installing homebrew to add it to the $PATH**

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/env-setup.sh)"
```

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/docker.sh)"
```

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/ssh-key-setup.sh setup)"
```

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/batch-ssh-key-setup.sh)"
```

```
/bin/bash -c "$(curl -fsSL https://raw.Githubusercontent.com/JoshKoiro/linux-container-setup/main/devconfig.sh)"
```

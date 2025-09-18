#!/bin/bash

# Download and Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Complete installation of homebrew
echo >> ~/.bashrc
echo  'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shell env)"
sudo nala install build-essential

# Download and Install eza
brew install eza

# Download and Install Neovim
brew install neovim

# Download and Install Lazygit (for Lazyvim)
brew install lazygit

# Download and Install ripgrep for lazyvim
brew install ripgrep

# Configure base Lazyvim configuration
# backup base config
mv ~/.config/nvim{,.bak}

# clone the repo for Lazyvim
git clone https://github.com/LazyVim/starter ~/.config/nvim

# remove the .git folder
rm -rf ~/.config/nvim/.git
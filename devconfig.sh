#!/bin/bash

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 22

# Verify the Node.js version:
node -v # Should print "v22.19.0".

# Verify npm version:
npm -v # Should print "10.9.3".

# Download and Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

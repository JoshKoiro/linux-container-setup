  #!/bin/bash
  
  # Download and Install Homebrew
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Complete installation of homebrew
  echo >> ~/.bashrc
  echo  'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shell env)"
  sudo nala install build-essential -y
  source ~./bashrc
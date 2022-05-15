#!/usr/bin/env bash

# instalar o Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Executar os comandos informados ao final da instalação do Homebrew, como
printf "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# instalar as dependências do Homebrew
sudo apt-get install build-essential

# instalar o GCC
brew install gcc

# instalar Oh My Posh
brew install jandedobbeleer/oh-my-posh/oh-my-posh

# instalar fontes
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip
mkdir ~/.fonts
unzip Meslo.zip -d ~/.fonts/Meslo
fc-cache -fv

# adicionar tema favorito ao .bashrc
printf "eval \"\$(oh-my-posh init bash --config 'https://github.com/JanDeDobbeleer/oh-my-posh/raw/main/themes/sonicboom_light.omp.json')\"" >> ~/.bashrc
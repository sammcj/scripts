#!/bin/bash

# Install Command Line Tools without Xcode
xcode-select --install
xcrun simctl delete unavailable

# vim
brew install macvim --HEAD --with-cscope --with-lua --with-override-system-vim --with-luajit --with-python

# zsh
brew install zsh && \
sudo sh -c 'echo $(brew --prefix)/bin/zsh >> /etc/shells' && \
chsh -s $(brew --prefix)/bin/zsh


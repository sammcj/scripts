#!/bin/bash
# Installs useful tools for developing and testing puppet code
# Assumes you have rubygems and homebrew installed

gem install -g tools_gemfile --no-document
gem cleanup

brew update
brew install jq shellcheck
brew cleanup

#!/bin/bash

# TODO
#
# - Split out secions to includes
# - Run post-setup security / BPA checks

### Misc Functions ###

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

### File Defaults ###

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi


### OSX Settings ###

# Check for updates daily
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ScheduleFrequency 1

# Set shell to zsh
case "$SHELL" in
  */zsh) : ;;
  *)
    fancy_echo "Changing your shell to zsh ..."
      chsh -s "$(which zsh)"
    ;;
esac


### Homebrew ###

append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

HOMEBREW_PREFIX="/usr/local"

if [ -d "$HOMEBREW_PREFIX" ]; then
  if ! [ -r "$HOMEBREW_PREFIX" ]; then
    sudo chown -R "$LOGNAME:admin" /usr/local
  fi
else
  sudo mkdir "$HOMEBREW_PREFIX"
  sudo chflags norestricted "$HOMEBREW_PREFIX"
  sudo chown -R "$LOGNAME:admin" "$HOMEBREW_PREFIX"
fi

if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    append_to_zshrc '# recommended by brew doctor'

    # shellcheck disable=SC2016
    append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

    export PATH="/usr/local/bin:$PATH"
fi

if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    append_to_zshrc '# recommended by brew doctor'

    # shellcheck disable=SC2016
    append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

    export PATH="/usr/local/bin:$PATH"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

fancy_echo "Updating Homebrew formulae ..."
brew update
brew bundle --file=- <<EOF
tap "thoughtbot/formulae"
tap "homebrew/services"
tap "caskroom/cask"
tap "homebrew/binary"
tap "homebrew/core"
tap "ravenac95/sudolikeaboss"
tap "tomanthony/brews"

brew "aria2"
brew "autoconf"
brew "automake"
brew "axel"
brew "bash"
brew "bison"
brew "cabal-install"
brew "cmake"
brew "coreutils"
brew "ctags"
brew "curl"
brew "ffmpeg"
brew "fzf"
brew "gawk"
brew "gd"
brew "gettext"
brew "git"
brew "git-extras"
brew "git-fixup"
brew "gitstats"
brew "gnu-sed"
brew "gnupg"
brew "gnuplot"
brew "gnutls"
brew "go"
brew "googler"
brew "graphviz"
brew "htop"
brew "httping"
brew "iftop"
brew "imagemagick"
brew "iperf3"
brew "itermocil"
brew "jq"
brew "lame"
brew "lftp"
brew "macvim"
brew "mercurial"
brew "mtr"
brew "ncdu"
brew "ncurses"
brew "openconnect"
brew "openssl"
brew "p7zip"
brew "pandoc"
brew "python"
brew "python3"
brew "readline"
brew "rsync"
brew "shellcheck"
brew "siege"
brew "sqlite"
brew "sudolikeaboss"
brew "tig"
brew "tmux"
brew "tmux-cssh"
brew "tree"
brew "wget"
brew "xz"
brew "yank"
brew "youtube-dl"
brew "zsh"
brew "libyaml" # should come after openssl
brew "rbenv"
brew "ruby-build"
EOF


### Setup Ruby ###

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
    rbenv rehash
  fi
}

fancy_echo "Configuring Ruby ..."
find_latest_ruby() {
  rbenv install -l | grep -v - | tail -1 | sed -e 's/^ *//'
}

ruby_version="$(find_latest_ruby)"
# shellcheck disable=SC2016
append_to_zshrc 'eval "$(rbenv init - --no-rehash)"' 1
eval "$(rbenv init -)"

if ! rbenv versions | grep -Fq "$ruby_version"; then
  RUBY_CONFIGURE_OPTS=--with-openssl-dir=/usr/local/opt/openssl rbenv install -s "$ruby_version"
fi

rbenv global "$ruby_version"
rbenv shell "$ruby_version"
gem update --system
gem_install_or_update 'bundler'
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

### Install Gems ###

gem install hiera-eyaml puppet-lint safe_yaml
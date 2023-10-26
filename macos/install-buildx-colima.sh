#!/usr/bin/env zsh

# Install brew command, when needed
brew --version
if [ $? != 0 ] ; then
    echo 'ℹ️  First install "brew" command'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Github CLI, when needed
gh --version
if [ $? != 0 ] ; then
    echo 'ℹ️  First install Github CLI'
    brew install gh
fi

# Install Buildx manually
# Helping ressources:
# - https://github.com/abiosoft/colima/discussions/273
# - https://docs.docker.com/buildx/working-with-buildx/#manual-download
# - https://cli.github.com/manual/gh_release_download
gh auth status
if [ $? != 0 ] ; then;
    gh auth login
fi
RELEASE_FILE_SUFFIX='darwin-arm64'

rm *.$RELEASE_FILE_SUFFIX
gh release download --repo 'github.com/docker/buildx' --pattern "*.$RELEASE_FILE_SUFFIX"
mkdir -p ~/.docker/cli-plugins
mv -f *.$RELEASE_FILE_SUFFIX ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
docker buildx version # verify installation
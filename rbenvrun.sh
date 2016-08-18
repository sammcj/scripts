#!/bin/bash
rbcmd="$@"; app=/var/vhost/redmine; rubyenv=production; rubyversion=rbx-2.2.9;

export RBENV_ROOT=$app/.rbenv
export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
export RAILS_ENV=$rubyenv
export RBENV_VERSION=$rubyversion

export HOME=$app

eval "$(rbenv init -)"

cd $app && RBENV_ROOT=$RBENV_ROOT PATH=$PATH RAILS_ENV=$RAILS_ENV RBENV_VERSION=$RBENV_VERSION exec $@

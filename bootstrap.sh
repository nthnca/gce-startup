#!/bin/bash

set -ue

# Log everything to /var/log/messages, should make it easier to debug any problems.
exec 1> >(logger -s -t $(basename $0)) 2>&1

# HOME isn't set by default for startup script.
export HOME=/root

# Don't directly use my repo, clone it and use your own.
# Using my repo is a significant security and stability risk for you, anything I change
# will affect you as well.

# Change the USER to your own github username and remove the exit line.
exit 1
USER=unknown
REPO=gce-startup

if [ -d "$HOME/$REPO" ]; then
  cd "$HOME/$REPO"
  git pull
else
  cd "$HOME"
  git clone "https://github.com/$USER/$REPO.git"
fi

cd "$HOME/$REPO"
./startup-script.sh

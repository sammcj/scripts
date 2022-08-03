#!/usr/bin/env bash

# TODO Fix - Important: Do not use a string containing an `=` character!
createVars() {
  <<Description
    All main enviroment variables need to be run in the main bash process
    using: source ./scripts/read_env.sh
Description

  echo "Creating environment variables..."
  while read var; do
    # Allow comments in .env file
    if [[ ! ${var:0:1} = "#" ]]; then
      k=${var%=*}
      v=${var#*=}
      if [[ ! -z "$k" ]]; then
        echo "$k = $v"
        export $k=$v
      fi
    fi
  done <$1

  echo "Environment Variables Loaded!"
}

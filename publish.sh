#!/bin/bash
set -eu
hugo && cd public && rsync -avp --delete --exclude .git . "${HOME}/src/github.com/marcopaganini/marcopaganini.github.io"

#!/bin/bash
set -eu
hugo && cd public && rsync -avp --delete --exclude .git . "${HOME}/github/marcopaganini/marcopaganini.github.io"

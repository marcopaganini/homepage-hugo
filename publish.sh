#!/bin/bash
set -e
hugo && cd public && rsync -avp --delete --exclude .git . $HOME/github/marcopaganini/marcopaganini.github.io

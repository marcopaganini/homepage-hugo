#!/bin/bash
# Publish the current site to the github homepages.

set -eu -o pipefail

TEMPDIR="$(mktemp -d)"
readonly TEMPDIR

readonly GITHUB_IO_URL="git@github.com:marcopaganini/marcopaganini.github.io.git"
trap 'rm -rf "${TEMPDIR}"' exit

function main {
  head="$(git rev-parse --short HEAD)"

  # Generate HTML page.
  rm -rf public
  hugo

  # Clone a fresh version of the github.io repo.
  git clone "${GITHUB_IO_URL}" "${TEMPDIR}"
  rsync -avp --delete --exclude .git "public/" "${TEMPDIR}"
  cd "${TEMPDIR}"
  git add -A
  git commit -m "Sync to upstream commit ${head}"
  git push
}


main "${@}"

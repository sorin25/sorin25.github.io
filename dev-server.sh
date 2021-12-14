#!/bin/bash
WORKDIR=$(realpath $(dirname $0)/docs)
docker run --name blog_dev --rm --volume="$WORKDIR:/srv/jekyll" --publish 5000:5000 -d \
  jekyll/jekyll jekyll serve


#!/bin/bash
WORKDIR=$(realpath $(dirname $0)/)
docker rm blog_dev

docker run --name blog_dev --volume="$WORKDIR:/srv/jekyll" --publish 4000:4000 -d \
  jekyll/jekyll jekyll serve


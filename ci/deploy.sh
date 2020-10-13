#!/usr/bin/env bash

set -xe

if [ -z ${EC2_SECRET+x} ]; then exit 1; fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DURATION=1m

eval $(ssh-agent)
ssh-add - <<< "${EC2_SECRET}"

# substitute environment variables in docker-compose.yml
DOCKER_COMPOSE="${SCRIPT_DIR}"/../aws/docker-compose.yml
envsubst < "${DOCKER_COMPOSE}" > "${DOCKER_COMPOSE}".tmp
mv "${DOCKER_COMPOSE}".tmp "${DOCKER_COMPOSE}"

# scp to ec2 the docker-compose.yml as docker-compose.yml.new
scp -o StrictHostKeyChecking=no "${DOCKER_COMPOSE}" ec2-user@ec2-3-120-244-69.eu-central-1.compute.amazonaws.com:docker-compose.yml.new

# ssh to aws ec2 (you'll need to have to add the .pem key to github somehow)
ssh -o StrictHostKeyChecking=no ec2-user@ec2-3-120-244-69.eu-central-1.compute.amazonaws.com << EOF
  set -xe

  # login to ecr
  aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 955603615851.dkr.ecr.eu-central-1.amazonaws.com

  # pull new images from ecr (docker-compose -f docker-compose.yml.new pull)
  docker-compose -f docker-compose.yml.new pull

  # stop running containers (down)
  docker-compose -f docker-compose.yml down

  # rename old compose file (.old)
  mv docker-compose.yml docker-compose.yml.old

  # rename new compose file
  mv docker-compose.yml.new docker-compose.yml

  # start new containers (up -d)
  docker-compose -f docker-compose.yml up -d

  # remove old compose file
  rm docker-compose.yml.old

  # remove old containers (docker system prune (+ make sure not to delete too new images, just in case))
  docker system prune --filter "util=${DURATION}"

EOF
# profit!

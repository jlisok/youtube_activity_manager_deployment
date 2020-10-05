#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
EC2_SECRET="${secrets.EC2_KEY}"
TIMESTAMP=$(date --rfc-3339=ns)

eval $(ssh-agent)
ssh-add - <<< "${EC2_SECRET}"

# scp to ec2 the docker-compose.yml as docker-compose.yml.new
scp "${SCRIPT_DIR}"/../aws/docker-compose.yml ec2-user@ec2-3-120-244-69.eu-central-1.compute.amazonaws.com:docker-compose.yml.new

# ssh to aws ec2 (you'll need to have to add the .pem key to github somehow)
ssh ec2-user@ec2-3-120-244-69.eu-central-1.compute.amazonaws.com

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
docker system prune --filter "util=${TIMESTAMP}"

# profit!
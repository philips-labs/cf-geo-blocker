#!/usr/bin/env sh
set -e

#
# Usage: ./build.sh [-y]
# Purpose: This script will build a container image and push it to the
#          HSDP Docker registry. It can look for values in a dotenv file
#          or prompt for the values.
#          If passed a `-y` flag, it assumes all values are in the dotenv and
#          will not prompt.
#

# Define a dotenv file if desired
ENV_FILE=./.env
DOCKERFILE=Dockerfile
PARAMETERS=(DOCKER_REGISTRY DOCKER_NAMESPACE DOCKER_IMAGE DOCKER_TAG DOCKER_USERNAME DOCKER_PASSWORD)

# Read and populate the dotenv file if present
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport; source "${ENV_FILE}"; set +o allexport
fi

# Was the debug attribute set?
if [[ $DEBUG == true ]]; then
  set -x
fi
echo "[$(date)]; DEBUG: ${DEBUG}"

# Iterate over the required build parameters
for parameter in ${PARAMETERS[@]}; do

  if [[ $1 == "-y" ]]; then
    if [[ -z "${!parameter}" ]]; then
      echo "[$(date)]; ERROR; Variable not define in \$ENV_FILE, please add or run build script without the '-y' flag: ${parameter}"
      exit
    fi
    if [[ $(echo $parameter | tr '[:upper:]' '[:lower:]']) != *"password"*  ]]; then
       echo "[$(date)]; Using $parameter: ${!parameter}"
    fi
    export $parameter=${!parameter}
  else
    default_value=${!parameter}
    if [[ $(echo $parameter | tr '[:upper:]' '[:lower:]']) == *"password"*  ]]; then
       unset default_value
       read -sp "[$(date)]; $parameter: " $parameter
    else
      read -p "[$(date)]; $parameter [${default_value}]: " entered_value && export $parameter=${entered_value:="${default_value}"}
    fi
  fi
done

# Build and push the docker image to HSDP's Docker registry
echo "[$(date)]; Logging into Docker regitry: ${DOCKER_REGISTRY}"
docker login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD}
echo "[$(date)]; Building Docker image: ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}:${DOCKER_TAG}"
#docker build --no-cache -t "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}:${DOCKER_TAG}" -f ${DOCKERFILE} .
docker build -t "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}:${DOCKER_TAG}" -f ${DOCKERFILE} .
echo "[$(date)]; Pushing Docker image to registry"
docker push "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}:${DOCKER_TAG}"
echo "[$(date)]; Build complete: $?"

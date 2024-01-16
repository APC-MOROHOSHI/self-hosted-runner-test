#!/bin/sh
INSTALLATION_ACCESS_TOKEN=$(./generate_installation_access_token.sh)

registration_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
echo "Requesting registration URL at '${registration_url}'"

payload=$(curl -sSX POST -H "Authorization: token ${INSTALLATION_ACCESS_TOKEN}" ${registration_url})
RUNNER_TOKEN=$(echo "${payload}" | jq .token --raw-output --exit-status)

if [ $? -ne 0 ]; then
  echo "Failed to get a new RUNNER_TOKEN."
  echo "Response body:"
  echo "${payload}"
  echo
  echo "Please check INSTALLATION_ACCESS_TOKEN or related settings."
  exit 1
fi

export RUNNER_TOKEN

./config.sh \
    --labels ${GLOBAL_ENVIRONMENT} \
    --name $(hostname) \
    --token ${RUNNER_TOKEN} \
    --url https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY} \
    --work ${RUNNER_WORKDIR} \
    --unattended \
    --replace

remove() {
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM

./run.sh "$*" &

wait $!
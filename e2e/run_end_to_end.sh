#!/usr/bin/env bash

#
#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

shopt -s nocasematch
set -u # nounset
set -E # errtrace
set -o pipefail

function help {
  echo " "
  echo "USAGE"
  echo "    --data-path                     [OPTIONAL] The data path. Default: ./data"
  echo "    --plugin-version                [OPTIONAL] The plugin version. Default: the current branch name"
  echo "    --skip-tests                    [OPTIONAL] Skip the tests"
  echo "    -h/--help                       Usage information."
  echo " "
  echo "COMPATABILITY"
  echo "     bash >= 4.0 is required."
  echo " "
}

# Require bash >= 4
if (( BASH_VERSINFO[0] < 4 )); then
  >&2 echo "ERROR> bash >= 4.0 is required" >&2
  help
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
PLUGIN_ROOT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. > /dev/null && pwd)"
DATA_PATH="${ROOT_DIR}/data"
TEST_PATH="${ROOT_DIR}/tests"
TEST_OUTPUT_PATH="${ROOT_DIR}/test_output"
PROJECT_NAME="metron-bro-plugin-kafka"
SKIP_TESTS='false'

cd "${PLUGIN_ROOT_PATH}" || { echo "NO PLUGIN ROOT" ; exit 1; }
# we may not be checked out from git, check and make it so that we are since
# zkg requires it

git status &>/dev/null
rc=$?; if [[ ${rc} != 0 ]]; then
  echo "zkg requires the plugin to be a git repo, creating..."
  git init .
  rc=$?; if [[ ${rc} != 0 ]]; then
    echo "ERROR> FAILED TO INITIALIZE GIT IN PLUGIN DIRECTORY. ${rc}"
  exit ${rc}
  fi
  git add .
  rc=$?; if [[ ${rc} != 0 ]]; then
    echo "ERROR> FAILED TO ADD ALL TO GIT PLUGIN DIRECTORY. ${rc}"
  exit ${rc}
  fi
  git commit -m 'docker run'
  rc=$?; if [[ ${rc} != 0 ]]; then
    echo "ERROR> FAILED TO COMMIT TO GIT MASTER IN PLUGIN DIRECTORY. ${rc}"
  exit ${rc}
  fi
  echo "git repo created"
fi

# set errexit for the rest of the run
set -e

# use the local hash as refs will use remotes by default
PLUGIN_VERSION=$(git rev-parse --verify HEAD)

# Handle command line options
for i in "$@"; do
  case $i in
  #
  # SKIP_TESTS
  #
  #   --skip-tests
  #
    --skip-tests)
      SKIP_TESTS=true
      shift # past argument
    ;;
  #
  # DATA_PATH
  #
    --data-path=*)
      DATA_PATH="${i#*=}"
      shift # past argument=value
    ;;
  #
  # PLUGIN_VERSION
  #
  #   --plugin-version
  #
    --plugin-version=*)
      PLUGIN_VERSION="${i#*=}"
      shift # past argument=value
    ;;
  #
  # -h/--help
  #
    -h | --help)
      help
      exit 0
      shift # past argument with no value
    ;;
  esac
done

function docker_compose_up {
  COMPOSE_PROJECT_NAME="${PROJECT_NAME}" \
    DATA_PATH="${DATA_PATH}" \
    TEST_OUTPUT_PATH="${TEST_OUTPUT_PATH}" \
    TEST_PATH="${TEST_PATH}" \
    PLUGIN_VERSION="${PLUGIN_VERSION}" \
    docker-compose up -d --build
}

function docker_compose_down {
  COMPOSE_PROJECT_NAME="${PROJECT_NAME}" \
    DATA_PATH="${DATA_PATH}" \
    TEST_OUTPUT_PATH="${TEST_OUTPUT_PATH}" \
    TEST_PATH="${TEST_PATH}" \
    PLUGIN_VERSION="${PLUGIN_VERSION}" \
    docker-compose down
}

cd "${ROOT_DIR}"
echo "Running the end to end tests with"
echo "COMPOSE_PROJECT_NAME = ${PROJECT_NAME}"
echo "PLUGIN_VERSION       = ${PLUGIN_VERSION}"
echo "DATA_PATH            = ${DATA_PATH}"
echo "TEST_OUTPUT_PATH     = ${TEST_OUTPUT_PATH}"
echo "SKIP_TESTS           = ${SKIP_TESTS}"
echo "==================================================="

if [[ "${SKIP_TESTS}" == 'true' ]]; then
  docker_compose_up

  echo "Run complete"
  echo "You may now work with the containers if you will.  Run finish_end_to_end.sh when you are done"
  exit
fi

# Create the example tests from the README
# TODO
#awk -f "${SCRIPT_DIR}"/extract_example_code_blocks.awk ../README.md | sed 's/^```.*//g' # TODO: Now what?

# TODO: Run all of the tests
# for x in y; do
#docker_compose_up
# Do things
#docker_compose_down
# done

echo ""
echo "Run complete"
echo "The kafka and zeek output can be found at ${TEST_OUTPUT_PATH}"


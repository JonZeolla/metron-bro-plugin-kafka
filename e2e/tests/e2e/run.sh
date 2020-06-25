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
set -e # errexit
set -o pipefail

#
# bootstraps and runs the test
#

ROOT_PATH='/root'
DATA_PATH="${ROOT_PATH}/data"
TEST_FOLDER_NAME="$(dirname "${BASH_SOURCE[0]}")"
TEST_PATH="${ROOT_PATH}/code/e2e/tests/${TEST_FOLDER_NAME}"
LOAD_PATH="/usr/local/zeek/share/zeek/site/test"
CONTAINER_SCRIPTS_PATH="${ROOT_PATH}/code/e2e/containers/zeek"
DATE=$(date)
LOG_DATE=${DATE// /_}
TEST_OUTPUT_PATH="${ROOT_PATH}/test_output/"${LOG_DATE//:/_}

# Link the test into the load path
ln -s "${TEST_PATH}" "${LOAD_PATH}"

# Download the pcaps
"${TEST_PATH}"/download_sample_pcaps.sh --data-path="${DATA_PATH}"

# TODO: Move this into btest?  Maybe another run_test.sh?
# for each pcap in the data directory, we want to
# run zeek then read the output from kafka
# and output both of them to the same directory named
# for the date/pcap
for file in "${DATA_PATH}"/**/*.pcap*
do
  # get the file name
  BASE_FILE_NAME=$(basename "${file}")
  DOCKER_DIRECTORY_NAME=${BASE_FILE_NAME//\./_}

  mkdir "${TEST_OUTPUT_PATH}/${DOCKER_DIRECTORY_NAME}" || exit 1
  echo "MADE ${TEST_OUTPUT_PATH}/${DOCKER_DIRECTORY_NAME}"

  # TODO: We have an issue.  Processing data files makes the topics, so we can't query until that happens.
  # get a list of kafka topics
  KAFKA_TOPICS=$("${CONTAINER_SCRIPTS_PATH}"/docker_run_get_kafka_topics.sh)

  # loop through each kafka topic
  while IFS= read -r KAFKA_TOPIC; do
    # get the offsets in kafka for the provided topic
    # this is where we are going to _start_, and must happen
    # before processing the pcap

    # If the script exits with an error, set the offset to 0, assuming the
    # topic has not been created yet
    OFFSETS=$("${CONTAINER_SCRIPTS_PATH}"/docker_run_get_offset_kafka.sh --kafka-topic="${KAFKA_TOPIC}" || echo "0")

    "${CONTAINER_SCRIPTS_PATH}"/process_data_file.sh --pcap-file-name="${BASE_FILE_NAME}" --output-directory-name="${DOCKER_DIRECTORY_NAME}"

    # loop through each partition
    while IFS= read -r line; do
      # shellcheck disable=SC2001
      OFFSET=$(echo "${line}" | sed "s/^${KAFKA_TOPIC}:.*:\(.*\)$/\1/")
      # shellcheck disable=SC2001
      PARTITION=$(echo "${line}" | sed "s/^${KAFKA_TOPIC}:\(.*\):.*$/\1/")

      echo "KAFKA_TOPIC-------------> ${KAFKA_TOPIC}"
      echo "PARTITION---------------> ${PARTITION}"
      echo "OFFSET------------------> ${OFFSET}"

      KAFKA_OUTPUT_FILE="${TEST_OUTPUT_PATH}/${DOCKER_DIRECTORY_NAME}/kafka-output.log"
      "${CONTAINER_SCRIPTS_PATH}"/docker_run_consume_kafka.sh --offset="${OFFSET}" --partition="${PARTITION}" --kafka-topic="${KAFKA_TOPIC}" 1>>"${KAFKA_OUTPUT_FILE}" 2>/dev/null
    done <<< "${OFFSETS}"
  done <<< "${KAFKA_TOPICS}"

  "${CONTAINER_SCRIPTS_PATH}"/split_kafka_output_by_log.sh --log-directory="${TEST_OUTPUT_PATH}/${DOCKER_DIRECTORY_NAME}"
done

"${CONTAINER_SCRIPTS_PATH}"/print_results.sh --test-directory="${TEST_OUTPUT_PATH}"

"${CONTAINER_SCRIPTS_PATH}"/analyze_results.sh --test-directory="${TEST_OUTPUT_PATH}"

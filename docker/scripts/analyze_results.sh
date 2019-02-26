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
#set -u # nounset disabled
set -e # errexit
set -E # errtrap
set -o pipefail

#
# Analyzes the results.csv files to identify issues
#

function help {
  echo " "
  echo "usage: ${0}"
  echo "    --test-directory           [REQUIRED] The directory for the tests"
  echo "    -h/--help                  Usage information."
  echo " "
  echo " "
}

SCRIPT_NAME=$(basename -- "$0")
TEST_DIRECTORY=
declare -A UNEQUAL_RESULTS
declare -a LOG_NAMES
declare -A LOG_OCCURRENCE
declare -A UNIQ_UNEQUAL_RESULTS
declare -r txtDEFAULT='\033[0m'
# shellcheck disable=SC2034
declare -r txtERROR='\033[0;31m'
# shellcheck disable=SC2034
declare -r txtWARN='\033[0;33m'

# Handle command line options
for i in "$@"; do
  case $i in
  #
  # TEST_DIRECTORY
  #
  #   --test-directory
  #
    --test-directory=*)
      TEST_DIRECTORY="${i#*=}"
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

  #
  # Unknown option
  #
    *)
      UNKNOWN_OPTION="${i#*=}"
      _echo ERROR "unknown option: $UNKNOWN_OPTION"
      help
    ;;
  esac
done

if [[ -z "$TEST_DIRECTORY" ]]; then
  echo "$TEST_DIRECTORY must be passed"
  exit 1
fi

echo "Running ${SCRIPT_NAME} with"
echo "TEST_DIRECTORY = $TEST_DIRECTORY"
echo "==================================================="

## Main functions
function _echo() {
  color="txt${1:-DEFAULT}"
  case "${1}" in
    ERROR)
      >&2 echo -e "${!color}${1}> ${2}${txtDEFAULT}"
      ;;
    WARN)
      echo -e "${!color}${1}> ${2}${txtDEFAULT}"
      ;;
    *)
      echo -e "${!color}${1}> ${2}${txtDEFAULT}"
      ;;
  esac
}

function count_occurrences_of_each_log_file
{
  # Count the number of occurences of each log name
  for LOG_NAME in "${LOG_NAMES[@]}"; do
    (( ++LOG_OCCURRENCE["${LOG_NAME}"] ))
  done
}

function check_for_unequal_log_counts
{
  RESULTS_FILE="${1}"

  # Get the pcap folder name from the provided file
  # shellcheck disable=SC2001
  PCAP_FOLDER="$( cd "$( dirname "${RESULTS_FILE}" )" >/dev/null 2>&1 && echo "${PWD##*/}")"

  # Check each log line in the provided log file for unequal results
  for LOG_NAME in "${LOG_NAMES[@]}"; do
    # For each log in the provided results, identify any unequal log counts
    UNEQUAL_LOG=$(awk -F\, -v log_name="${LOG_NAME}" '$1 == log_name && $2 != $3 {print $1}' "${RESULTS_FILE}")

    # Create a space separated list of unequal logs to simulate a
    # multidimensional array
    if [[ -n "${UNEQUAL_LOG}" ]]; then
      if [[ "${#UNEQUAL_RESULTS[${PCAP_FOLDER}]}" -eq 0 ]]; then
        UNEQUAL_RESULTS["${PCAP_FOLDER}"]="${UNEQUAL_LOG}"
      else
        UNEQUAL_RESULTS["${PCAP_FOLDER}"]+=" ${UNEQUAL_LOG}"
      fi
    fi
  done
}

function print_unequal_results
{
  # Output a table with the pcap file and log name details where the imbalance
  # was detected
  {
  echo "PCAP FOLDER,LOG NAME"

  for KEY in "${!UNEQUAL_RESULTS[@]}"; do
    # This must be done because we are simulating multidimensional arrays due to
    # the lack of native bash support
    for VALUE in ${UNEQUAL_RESULTS[${KEY}]}; do
      echo "${KEY},${VALUE}"
    done
  done
  } | column -t -s ','
}

function print_log_comparison_insights
{
  # Load the log to instance count mapping from UNEQUAL_RESULTS into a new
  # associative array
  # shellcheck disable=SC2046
  declare -A $(echo "${UNEQUAL_RESULTS[@]}" | tr ' ' '\n' | sort | uniq -c | awk '{print "UNIQ_UNEQUAL_RESULTS["$2"]="$1}')

  # Compare each log type's instances of inequality to the total number of
  # instances of each log.  If they are equal, this indicates that there may be
  # a log-type related issue.
  #
  # For example, if count_occurrences_of_each_log_file identified that there
  # were 10 instances of http logs across all of the `results.csv` files,
  # ${LOG_OCCURRENCE[http]} should equal 10. If check_for_unequal_log_counts
  # also found 10 instances where the http bro and kafka log counts were
  # imbalanced, ${UNIQ_UNEQUAL_RESULTS[http]} would also have 10 entries,
  # causing us to warn the user of that insight.
  for KEY in "${!UNIQ_UNEQUAL_RESULTS[@]}"; do
    if [[ "${UNIQ_UNEQUAL_RESULTS[${KEY}]}" == "${LOG_OCCURRENCE[${KEY}]}" ]]; then
      _echo WARN "None of the ${KEY} log counts were the same between bro and kafka."
    fi
  done
}

## Main
# Move over to the docker area
cd "${TEST_DIRECTORY}" || exit 1
# Get a list of results files
RESULTS_FILES=$(find "${TEST_DIRECTORY}" -name "results.csv")
# Analyze each results file for issues
for file in $RESULTS_FILES; do
  # Capture the first column (the log names) of the provided file's contents in
  # the array LOG_NAMES, excluding the header
  mapfile -s 1 -t LOG_NAMES < <(awk -F\, '{print $1}' "${file}")

  count_occurrences_of_each_log_file
  check_for_unequal_log_counts "${file}"
done

if [[ "${#UNEQUAL_RESULTS[@]}" -gt 0 ]]; then
  _echo ERROR "INEQUALITY FOUND IN BRO AND KAFKA LOG COUNTS"
  echo ""

  print_unequal_results
  print_log_comparison_insights

  exit 1
fi


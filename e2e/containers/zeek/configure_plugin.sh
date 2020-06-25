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
shopt -s globstar nullglob
shopt -s nocasematch
set -u # nounset
set -e # errexit
set -E # errtrace
set -o pipefail

#
# Perform baseline configuration of the Zeek docker container
#

# Load directory where the test should be placed
echo '@load test' >> /usr/local/zeek/share/zeek/site/local.zeek

# Comment out the load statement for "log-hostcerts-only.zeek" in zeek's
# default local.zeek as of 3.1.2 in order to log all certificates to x509.log
sed -i 's%^@load protocols/ssl/log-hostcerts-only%#&%' /usr/local/zeek/share/zeek/site/local.zeek


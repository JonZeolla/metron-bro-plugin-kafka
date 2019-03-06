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

# @TEST-EXEC: bro ../../../scripts/Apache/Kafka/ %INPUT > output
# @TEST-EXEC: btest-diff output

module Kafka;

redef logs_to_send = set(HTTP::LOG, Conn::LOG);
redef topic_name = "";

event bro_init() &priority=-5
{
  # Find all of the log filters that have the WRITER_KAFKAWRITER writer set,
  # and check the effective kafka topic based on the expected configuration
  # priorities
  for (log_id in logs_to_send) {
    for (filter_name in Log::get_filter_names(log_id)) {
      for (filter in Log::get_filter(log_id, filter_name)) {
        if ( filter$writer == "Log::WRITER_KAFKAWRITER" ) {
	  print SelectTopicName(filter$conf$topic_name, topic_name, filter$path);
        }
      }
    }
  }
}


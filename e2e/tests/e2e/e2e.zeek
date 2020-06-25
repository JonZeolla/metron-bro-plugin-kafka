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

redef Kafka::logs_to_send = set(HTTP::LOG, DNS::LOG, Conn::LOG, DPD::LOG, FTP::LOG, Files::LOG, Known::CERTS_LOG, SMTP::LOG, SSL::LOG, Weird::LOG, Notice::LOG, DHCP::LOG, SSH::LOG, Software::LOG, RADIUS::LOG, X509::LOG, RFB::LOG, Stats::LOG, CaptureLoss::LOG, SIP::LOG);
redef Kafka::topic_name = "zeek";
redef Kafka::tag_json = T;
redef Kafka::kafka_conf = table(["metadata.broker.list"] = "kafka-1:9092,kafka-2:9092");
redef Kafka::logs_to_exclude = set(Conn::LOG, DHCP::LOG);
redef Known::cert_tracking = ALL_HOSTS;
redef Software::asset_tracking = ALL_HOSTS;

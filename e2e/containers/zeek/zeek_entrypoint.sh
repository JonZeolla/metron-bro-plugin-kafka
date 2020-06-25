#!/usr/bin/env bash

set -u # nounset
set -e # errexit
set -E # errtrace
set -o pipefail

# Print the zeek version
zeek --version

# Print the librdkafka version
python3 - <<END
from ctypes import cdll
from re import findall
# Load the librdkafka shared object
dll = cdll.LoadLibrary("/usr/local/lib/librdkafka.so")
# Get the version and lpad it to 8 characters + 2 characters for the "0x" pad
version = f"{dll.rd_kafka_version():#0{10}x}"
# Convert the version to semver by breaking it into two character chunks,
# stripping any "0" padding, and ignoring the first and last elements. Per the
# rd_kafka_version() documentation the last element will always be "ff" for
# final releases
version_list = findall(".{1,2}", version)
version_list_without_padding = [s.lstrip("0") for s in version_list]
semver = ".".join(version_list_without_padding[1:-1])
print("librdkafka version " + semver)
END

# Print the plugin version
echo "metron-bro-plugin-kafka version $(zeek -N Apache::Kafka | sed 's/^Apache::Kafka .*version \(.*\))/\1/g')"

# Open a bash shell
/usr/bin/env bash


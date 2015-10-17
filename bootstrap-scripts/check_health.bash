#!/usr/bin/env bash

monit_user="$1"
monit_pass="$2"
monit_addr="$3"
monit_port="$4"
shift 4
job_names="$@"

is_unhealthy=0

for service_name in ${job_names}; do
  monit_status=$(curl -s -u "${monit_user}:${monit_pass}" "http://${monit_addr}:${monit_port}/_status?format=xml")
  if [[ "$?" != 0 ]]; then
    echo "failed to reach monit at: http://${monit_addr}:${monit_port} using provided username and password"
    exit 2
  fi
  service_health=$(echo "${monit_status}" | xmlstarlet sel -t -m "monit/service[name='${service_name}']" -v status)
  echo "${service_name} => ${service_health}"
  if [[ 0 != "${service_health}" ]]; then
    is_unhealthy=2
  fi
done

exit $is_unhealthy

#!/bin/bash
while true
do
  IP=$(ip route | grep default | cut -d\  -f3)
  STATUSCODE=$(curl -s --output /dev/null --write-out "%{http_code}" $IP:8500/v1/catalog/services)
  ZK=$(curl -s $IP:8500/v1/catalog/service/zookeeper-2181)
  if [ "$STATUSCODE" != "200" ]; then
    echo "curl failed with status code $STATUSCODE, retrying in 5 seconds..."
    sleep 5
  elif [ "$ZK" == "[]" ]; then
    echo "Zookeeper not yet ready, retrying in 5 seconds..."
    sleep 5
  else
    regex="Address\":\"([1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9]\.[1-2]?[0-9]?[0-9])\",\""; 
    [[ $ZK =~ $regex ]]
    export ZK=${BASH_REMATCH[1]}
    echo "Zookeeper found at $ZK, starting mesos"
    break
  fi
done
docker -H unix:///docker.sock pull mesosphere/mesos-slave:0.20.1
docker -H unix:///docker.sock run --rm -i --name=mesos_slave --privileged --net=host -v /sys:/sys -v /usr/bin/docker:/bin/docker:ro -v /var/run/docker.sock:/docker.sock -v /lib64/libdevmapper.so.1.02:/lib/libdevmapper.so.1.02:ro -v /lib64/libpthread.so.0:/lib/libpthread.so.0:ro -v /lib64/libsqlite3.so.0:/lib/libsqlite3.so.0:ro -v /lib64/libudev.so.1:/lib/libudev.so.1:ro mesosphere/mesos-slave:0.20.1 --ip=$HOST_IP --containerizers=docker --master=zk://$ZK:2181/mesos --work_dir=/var/lib/mesos/slave --log_dir=/var/log/mesos/slave

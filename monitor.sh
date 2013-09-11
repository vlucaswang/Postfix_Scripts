#!/bin/sh

monitor_file=/root/monitor.txt

while:
do
  vmr='vmstat | tail -1 | awk '{print $1}''
  if [ ${vmr} -gt 4]
    then
    date >> $monitor_file
    vmstat >> $monitor_file
    netstat -anp >> $monitor_file
    ps -aux >> $monitor_file
    last >> $monitor_file
    tail -10 /var/log/messages >> $monitor_file
  fi
  sleep 60
done

#!/bin/sh
netstat -an | grep :25 | grep -v 127.0.0.1 | awk '{print $5}' | sort | awk -F: '{print $1}' | uniq -c | awk '$1 > 100'
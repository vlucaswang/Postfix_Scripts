#!/bin/sh

find /home/postfix/mldata -name lock -cmin +30 -exec rm -f {} \;


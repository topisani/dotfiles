#!/bin/sh

# connect.sh

# Usage:
# $ connect.sh <device> <port speed>
# Example: connect.sh /dev/ttyS0 9600

# Set up device
stty -F $1 $2

# Let cat read the device $1 in the background
cat $1 &

# Capture PID of background process so it is possible to terminate it when done
bgPid=$!

# Read commands from user, send them to device $1
while read cmd
do
   echo "$cmd" 
done > $1

# Terminate background read process
kill $bgPid

#!/bin/bash
echo 	--- RUNNING BASIC TESTS ---
./basicTests.sh

echo 	--- TESTING PING ---
./testPing.sh

echo 	--- TESTING TRACEROUTE ---
./testTrace.sh

echo 	--- TESTING MESSAGE ---
./testMsg.sh

echo 	--- TESTING FTP ---
./testFTP.sh

echo 	--- TESTING COMPLETE --- 



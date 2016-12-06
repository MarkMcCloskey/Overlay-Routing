#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in



echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < pingTest2.in
cat console_n1

echo --- TEST 3 TWO NODES MORE PINGS ---
ruby controller.rb pingNodes2.txt config < pingTest3.in
cat console_n1

echo -- TEST 4 3 NODE TEST ---
ruby controller.rb pingNodes3.txt config < pingTest4.in
cat console_n1
	
echo --- TEST 5 4 NODE TEST ---
ruby controller.rb pingNodes3.txt config < pingTest5.in
cat console_n1

echo --- TEST 6 TIMEOUT CASE ---
ruby controller.rb pingNodes3.txt config < pingTest6.in
cat console_n1

echo --- TESTING COMPLETE --- 

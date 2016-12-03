#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in

echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < traceTest2.in

cat console_n1
echo 
cat console_n2

echo --- RUNNING TEST 3 ---
ruby controller.rb traceNodes3.txt config < traceTest3.in

echo Node 1 Console:
cat console_n1
echo
echo Node 2 Console:
cat console_n2
echo 
echo Node 3 Console:
cat console_n3

echo --- TESTING COMPLETE --- 

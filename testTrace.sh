#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in

echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < traceTest2.in

cat console_n1

echo --- RUNNING TEST 3 ---
ruby controller.rb traceNodes3.txt config < traceTest3.in

echo Node 1 Console:
cat console_n1

echo --- RUNNING TEST 4 BACK TO BACK TRACE ---
ruby controller.rb traceNodes3.txt config < traceTest4.in

echo --- RUNNING FAR TRACE TEST ---
ruby controller.rb bigGraphNodes.txt quickConfig < traceTest5.in
echo Node 1 Console:
cat console_n1


echo
echo --- TRACE TESTING COMPLETE --- 

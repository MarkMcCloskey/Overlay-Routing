#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in



echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < msgTest2.in
cat console_n1
echo 
cat console_n2

echo --- RUNNING 3 NODE TEST ---
ruby controller.rb nodes.txt config < msgTest3.in
cat console_n1
echo
cat console_n3

echo --- RUNNING 4 NODE TEST ---
ruby controller.rb nodes.txt config < msgTest4.in
echo Node 1 Console:
cat console_n1
echo
echo Node 4 Console:
cat console_n4

echo --- TESTING COMPLETE --- 

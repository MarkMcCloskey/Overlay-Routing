#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in



echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < pingTest2.in
cat console_n1

echo --- TWO NODES MORE PINGS ---
ruby controller.rb pingNodes2.txt config < pingTest3.in
cat console_n1

echo --- TESTING COMPLETE --- 

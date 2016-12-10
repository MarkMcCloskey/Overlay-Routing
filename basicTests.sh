#!/bin/bash
#These tests are just to make sure that calling commands doesn't crash 
#the program

echo  --- TESTING NODE.RB COMPILATION --- 
ruby controller.rb basicNodes1.txt config < basicTest1.in

echo
echo --- TESTING COMMAND LINE PRINTING ---
ruby controller.rb basicNodes1.txt config < basicTest2.in
cat console_n1

echo
echo --- TESTING EDGE COMMANDS ---
ruby controller.rb basicNodes2.txt config < basicTest3.in
echo NODE 1 CONSOLE
cat console_n1
cat n1_t*

echo
echo --- TESTING NODE STATUS COMMANDS ---
ruby controller.rb basicNodes2.txt config < basicTest4.in
echo NODE 1 CONSOLE
cat console_n1
echo NODE 1 DUMPTABLE
cat t1_n1_dumptable.txt
cat t1_n2_dumptable.txt
echo

echo NODE 2 CONSOLE
cat console_n2
echo NODE 2 DUMPTABLE
cat n2_t1_dumptable.txt

make clean


echo
echo --- LET BIG GRAPH RUN A WHILE ---
ruby controller.rb bigGraphNodes.txt config < bigGraph.in
echo

echo
echo --- BASIC TESTING COMPLETE --- 

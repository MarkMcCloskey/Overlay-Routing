#!/bin/bash
#These tests are just to make sure that calling commands doesn't crash 
#the program

echo  --- TESTING NODE.RB COMPILATION --- 
ruby controller.rb basicNodes1.txt config < basicTest1.in

echo --- TESTING COMMAND LINE PRINTING ---
ruby controller.rb basicNodes1.txt config < basicTest2.in
cat console_n1
echo --- TESTING EDGE COMMANDS ---
ruby controller.rb basicNodes2.txt config < basicTest3.in

echo --- TESTING NODE STATUS COMMANDS ---
ruby controller.rb basicNodes2.txt config < basicTest4.in
echo NODE 1 CONSOLE
cat console_n1
echo NODE 2 CONSOLE
cat console_n2

echo --- TESTING COMPLETE --- 

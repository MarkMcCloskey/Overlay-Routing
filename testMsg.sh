#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in


echo
echo --- RUNNING SIMPLE TWO NODE TEST ---
echo
ruby controller.rb pingNodes2.txt config < msgTest2.in
cat console_n1
echo 
cat console_n2

echo
echo --- RUNNING 3 NODE TEST ---
echo
ruby controller.rb nodes.txt config < msgTest3.in
cat console_n1
echo
cat console_n3

echo
echo --- RUNNING 4 NODE TEST ---
echo
ruby controller.rb nodes.txt config < msgTest4.in
echo Node 1 Console:
cat console_n1
echo
echo Node 4 Console:
cat console_n4


echo 
echo --- MSG WITH SPACES ---
echo
ruby controller.rb nodes.txt config < msgTest5.in
echo	NODE 1 CONSOLE
cat console_n1
echo	NODE 2 CONSOLE
cat console_n2

echo
echo --- MSG WITH SPECIAL CHARACTERS ---
echo
ruby controller.rb pingNodes2.txt config < msgTest6.in
echo 	NODE 1 CONSOLE
cat console_n1
echo	NODE 2 CONSOLE
cat console_n2

echo
echo --- MSG WITH NEWLINE ---
echo
ruby controller.rb pingNodes2.txt config < msgTest7.in
echo 	NODE 1 CONSOLE
cat console_n1
echo	NODE 2 CONSOLE
cat console_n2

echo
echo --- RUNNING FAR MSG TEST ----
ruby controller.rb bigGraphNodes.txt quickConfig < msgTest8.in
echo	NODE 1 CONSOLE
cat console_n1
echo	NODE 11 CONSOLE
cat console_n11

echo
echo --- RUNNING LONG MESSAGE TEST ---
ruby controller.rb pingNodes2.txt config < msgTest9.in
echo NODE 1 CONSOLE
cat console_n1
echo NODE 2 CONSOLE
cat console_n2



echo
echo --- MSG TESTING COMPLETE --- 

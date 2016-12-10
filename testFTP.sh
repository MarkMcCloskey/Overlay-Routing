#!/bin/bash
echo  --- CHECKING NODE.RB COMPILATION --- 
ruby controller.rb pingNodes1.txt config < pingTest1.in

echo --- RUNNING SIMPLE TWO NODE TEST ---
ruby controller.rb pingNodes2.txt config < ftpTest1.in
echo console_n1
cat console_n1
echo
echo console_n2
cat console_n2

echo --- RUNNING SHITTY FILE TEST ---
ruby controller.rb pingNodes2.txt config < ftpTest2.in
echo CONSOLE_N1
cat console_n1
echo 
echo CONSOLE_N2
cat console_n2
echo --- RUNNING PDF TEST ---
ruby controller.rb pingNodes2.txt config < ftpTest3.in
echo	CONSOLE_N1
cat console_n1

echo	CONSOLE_N2
cat console_n2


echo
echo --- RUNNING BIG FILE TEST ---
echo

echo
echo --- RUNNING FAR FTP TEST ---
echo



echo --- TESTING COMPLETE --- 

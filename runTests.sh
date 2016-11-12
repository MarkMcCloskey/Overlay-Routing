#!/bin/bash
echo Running test 1.
ruby controller.rb nodes.txt config < test1.in

echo Running test 2.
ruby controller.rb nodes.txt config < test2.in
DIFF=$(diff console_n1 test2.out)
if [ "$DIFF" != "" ]
then
	echo TEST 2 FAILED
fi
make clean

echo Running test 3.
ruby controller.rb nodes.txt config < test3.in
DIFF=$(diff t1_n1_dumptable.txt test3n1.out)
if [ "$DIFF" != "" ]
then
	echo TEST 3-0 FAILED
fi
DIFF=$(diff t1_n2_dumptable.txt test3n2.out)
if [ "$DIFF" != "" ]
then
	echo TEST 3-1 FAILED
fi
make clean

echo Running testStatus
ruby controller.rb nodes.txt config < testStatus.in
DIFF=$(diff console_n1 testStatus.out)
if [ "$DIFF" != "" ]
then 
	echo TEST STATUS FAILED
fi
make clean



echo Testing Done!

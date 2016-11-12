test:
	ruby controller.rb nodes.txt config < test1.in
	ruby controller.rb nodes.txt config < test2.in

.PHONY : clean
clean : 
	@-rm console_*
	@-rm t1_*

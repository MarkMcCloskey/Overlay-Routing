require_relative "openFile"
require "test/unit"

class TestOpenFile < Test::Unit::TestCase

	def test_simple
		openFile = MyFile.new
		openFile.open("test.txt" ,"Hello, world")
	end
end

require_relative "timer"
require "test/unit"

class TestTimer < Test::Unit::TestCase
	def test_simple
		time = Timer.new
		puts time.startTime
		sleep 5
		puts time.curTime
		puts time.runTim
	end
end


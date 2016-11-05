class Timer
	DELTA_T = ONE_SECOND = 1
	attr_accessor :startTime, :curTime, :timeUpdater
	def initialize
		@startTime = Time.new
		@curTime = @startTime
		@timeUpdater = Thread.new {
			loop do
				sleep(DELTA_T)
				@curTime += DELTA_T
			end
		}

		def startTime
			return @startTime
		end

		def curTime
			return @curTime
		end

		def runTime
			return @curTime - @startTime
		end
	end
end


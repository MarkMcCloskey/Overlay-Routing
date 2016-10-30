class Timer
	DELTA_T = ONE_SECOND = 1

	def initialize
		@startTime = Time.new
		@curTime = @startTime
		@timeUpdater = Thread.new {
			loop do
				sleep(DELTA_T)
				$curTime += DELTA_T
			end
		}

		def startTime
			$startTime
		end

		def curTime
			$curTime
		end

		def runTime
			$curTime - $startTime
		end
	end
end


require 'thread'
Thread::abort_on_exception = true

def setup(dst, numPings, delay)
	puts "in setup"
	th = Thread.new do
		pingCounter = 0
		time = 0
		sleepTime = delay/2
		while pingCounter < numPings
			sleep sleepTime
			time += sleepTime
			if(time % delay == 0)
			STDOUT.puts dst +" "+ pingCounter.to_s + " "+ time.to_s
			pingCounter +=1  
			end
		end
	end
	th.join
end





setup(ARGV[0], ARGV[1].to_i, ARGV[2].to_i)

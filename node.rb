$port = nil
$hostname = nil
$routingTable = Hash.new
$timer = nil 

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
			@starTime
		end
		
		def curTime
			@curTime
		end

		def runTime
			@curTime - @startTime
		end
	end
end


# --------------------- Part 0 --------------------- # 
#srcip dstip dst
def edgeb(cmd)
	#update srcip routing table
	#connect to dstip using nodes.txt port #'s
	#
	$routingTable[cmd[1]] = 1
end

def dumptable(cmd)
	File.open(cmd[0], "w"){ |file| $routingTable.each do |key,value|
		puts $hostname,key,key,value
	end
	}

# $routingTable.each do |key,value|
#$hostname,key,key,value end
#{ |file| file.puts "test"}
end

def shutdown(cmd)
	STDOUT.flush
	STDERR.flush
	exit(0)
end



# --------------------- Part 1 --------------------- # 
def edged(cmd)
	STDOUT.puts "EDGED: not implemented"
end

def edgew(cmd)
	STDOUT.puts "EDGEW: not implemented"
end

def status()
	STDOUT.puts "STATUS: not implemented"
end


# --------------------- Part 2 --------------------- # 
def sendmsg(cmd)
	STDOUT.puts "SENDMSG: not implemented"
end

def ping(cmd)
	STDOUT.puts "PING: not implemented"
end

def traceroute(cmd)
	STDOUT.puts "TRACEROUTE: not implemented"
end

def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

# --------------------- Part 3 --------------------- # 
def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end




# do main loop here.... 
def main()

	while(line = STDIN.gets())
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; edged(args)
		when "EDGEW"; edgew(args)
		when "DUMPTABLE"; dumptable(args)
		when "SHUTDOWN"; shutdown(args)
		when "STATUS"; status()
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args)
		when "CIRCUIT"; circuit(args)
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port
	$timer = Timer.new
	#set up ports, server, buffers
	#create hash from nodes.txt nodeName => portNo
	#need AT LEAST 2 buffers 1  for command receipt and 1 for packets
	
	main()

end

def parseConfig(file)
	f = file.open
# for every line parse the value and store into global variables
#we'll need to use these variables throughout the nodes methods
end


setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])






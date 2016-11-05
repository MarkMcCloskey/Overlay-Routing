require 'thread'
require 'socket'

#given during node creation
$port = nil
$hostname = nil

#read in from config
$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil

#necessary variables
$routingTable = Hash.new
$timer = nil 
$nodesToPort = Hash.new
$nodesToSocket = Hash.new
$globalBuffer = Array.new 
$sendBuffer = Array.new 
$recvBuffer = Array.new 
$inPorts = Array.new
$outPorts = Array.new

class Timer
	DELTA_T = ONE_SECOND = 1
	attr_accessor :startTime, :curTime
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
			@startTime
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
		when "hostname"; puts $hostname
		when "updateInterval"; puts $updateInterval
		when "maxPayload"; puts $maxPayload
		when "pingTimeout"; puts $pingTimeout
		when "nodesToPort";puts $nodesToPort
		when "curTime"; puts $timer.curTime
		when "startTime"; puts $timer.startTime
		when "runTime"; puts $timer.runTime
		when "port"; puts $port
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port
	$timer = Timer.new
	parseConfig(config)
	parseNodes(nodes)
	#set up ports, server, buffers
	
	#needs to be threaded
	#server = TCPServer.new port
	#loop do 
	#	client = server.accept
	#	inPorts << client
	#end
	
	#create hash from nodes.txt nodeName => portNo
	#need AT LEAST 2 buffers 1  for command receipt and 1 for packets
	
	main()

end

def parseConfig(file)
	File.foreach(file){ |line|
		pieces = line.partition("=")
		if pieces[0] == "updateInterval"
			$updateInterval = pieces[2]
		elsif pieces[0] == "maxPayload"
			$maxPayload = pieces[2]
		elsif pieces[0] == "pingTimeout"
			$pingTimeout = pieces[2]
		end
	}
end

def parseNodes(file)
	File.foreach(file){ |line|
		pieces = line.partition(",")
		$nodesToPort[pieces[0]] = pieces[2].to_i
	}
end


setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])






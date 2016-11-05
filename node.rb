<<<<<<< HEAD
require 'thread'
require 'socket'

#given during node creation
$port = nil
$hostname = nil
=======
$port # This node's port number
$hostname # This node's name
$nodes # Hash of all nodes in the universe (nodeName => portNumber)

# Following Hashes only contain information with neighbors
$nextHop # nodeName => nodeName
$cost # nodeName => integer cost
$tcpH # Don't exactly know how TCP objects work in ruby so this might be modified
$neighbor # nodeName => boolean

$updateInteveral
$maxPayload
$pingTimeOut
$timeout

$intComBuf
$extComBuf
$packetBuf

$nextMsgId


# Main Loop Processor:
# 	While reading a line from the terminal
# 		send line to the internal command buffer

# Internal Command Processor:
#  	For every command in the internal command buffer
# 		Call its corresponding function

# Alternative Main Loop Processor:
# 	For every line from the terminal
# 		create a new thread for each function call

# Idk which one works or if thats how threads work fully

# Packet Processor:
#	For every packet in the packet buffer
# 		If the packets final destination is not this node
# 			forward the packet (extract final dst, call forwardPacket(packet, final dst))
# 		Else
# 			If ALL of the sibling packets are in the buffer
# 				Insert all of the sibling packets into an array (if they aren't already)
# 				and forward them to the external command buffer
# 			Else
# 				Continue

# External Command Procesor:
# 	For every packet array in the external command buffer (maybe we need a better name for this buffer)
# 		Call a function that reconstructs the payload from all of the packets
# 		Send the payload to its respective function. (This would be an external command function controller
# 		similar to what we have for terminal commands)

# 
>>>>>>> juan

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
<<<<<<< HEAD
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
=======
	srcIp = cmd[0]
	dstIp = cmd[1]
	dst = cmd[2]
	#is this a good idea?
	if ($neighbor[dst])
		STDOUT.puts "Edge Already Exists"
		return

	tcpH[$hostname] = connect(srcIp, dstIp)
	nextHop[dst] = dst
	cost[dst] = 1
	neighbor[dst] = true

	payload = [srcIp, $hostname].join(",")

	send("edgeb", payload, dst)
end

def edgebExt(cmd)
	srcIp = cmd[0]
	node = cmd[1]

	nextHop[node] = node
	cost[node] = 1

	neighbor[node] = true

	# If we decide to duplex or when we learn more about ruby tcp connections,
	# then write the code for it here



>>>>>>> juan
end

def dumptable(fileName)
	CSV.open(fileName, "wb") { |csv|
		$cost.each_key { |node|
			csv << [$hostname, node, $nextHop[node], $cost[node]]
		}
	}

end

# Close connections and empty buffers
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
<<<<<<< HEAD
	
	#needs to be threaded
	#server = TCPServer.new port
	#loop do 
	#	client = server.accept
	#	inPorts << client
	#end
	
	#create hash from nodes.txt nodeName => portNo
	#need AT LEAST 2 buffers 1  for command receipt and 1 for packets
	
=======

	# Reads the nodes file and stores its node => port$ into $nodes hash 
	readNodes(nodes)

	# Reads the config file and stores its contents into $updateInteveral,
	# $maxPayload, and $pingTimeOut
	readConfig(config)

	# Initializes the hashes used for the routing tables
	nextHop = Hash.new("-")
	cost = Hash.new(1.0/0.0) #inf
	cost[$hostname] = 0;

	# Initializes the hashes used for neighbor checking and TCP object connections
	neighbor = Hash.new
	tcpH = Hash.new

	# Initialized buffers
	$intComBuf = []
	$extComBuf = []
	$packetBuf = []

	# Unique ID used for each message. Incremented for every new message
	$nextMsgId = 0

	# Calls function that initializes the node to listen for incoming connection requests
	# Maybe should be replaced with a function that initializes all of the threads and
	# inside includes the listen function()
	listen()

>>>>>>> juan
	main()

end

<<<<<<< HEAD
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


=======
# Send function for commands from this node's terminal NOT for commands from other nodes
# Fragments the payload, adds the IP header to each packet, and sends each packet to
# the next node
def send(cmd, payload, dst)
	fragments = payload.chars.to_a.each_slice($maxPayload).to_a.map{|s| s.to_s}
	packets = createPackets(cmd, fragments, dst)

	packets.each { |p|
		tcpSend(p, $nextHop[dst])
	}
end

# Appends header to each fragment
def createPackets(cmd, fragments, dst)
	packets = []

	fragments.each_with_index { |f, idx|
		src = $hostname

		header = [src, dst, id, idx, cmd, fragFlag, fragOffset,len,
	    		ttl, routingType, routingType, path].join(",")

		p = header + ":" + f

		packets.push(p)
	}

	$nextMsgId = $nextMsgId + 1

	return packets
end

# Function called by packet buffer processors
def forwardPacket(packet,dst)
	#before you send possibly fragment
	#and nextHopwould be incorrect if it's a circuit
	#instead make it a variable and decide before this line
	#where it's going
	
	tcpSend(packet, $nextHop[dst])
end

# Function that actually calls the TCP function to send message
def tcpSend(packet, nextHop)
	tcp = $tcpH[nextHop]

	# Code for actually sending the packet to the next node here. 
	# (If there is a tcp error, ignore it and let the timeout handle it)


end
>>>>>>> juan
setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])






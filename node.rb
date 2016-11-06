require 'thread'
require 'socket'

#given during node creation
$port = nil
$hostname = nil
$nodes # Hash of all nodes in the universe (nodeName => portNumber)

# Following Hashes only contain information with neighbors
$nextHop # nodeName => nodeName
$cost # nodeName => integer cost
$tcpH # Don't exactly know how TCP objects work in ruby so this might be modified
$neighbor # nodeName => boolean

$timeout

$intComBuf
$extComBuf
$packetBuf

$nextMsgId

=begin
Main Loop Processor:
	While reading a line from the terminal
	send line to the internal command buffer

Internal Command Processor:
	For every command in the internal command buffer
 	Call its corresponding function

Alternative Main Loop Processor:
	For every line from the terminal
	create a new thread for each function call

Idk which one works or if thats how threads work fully

Packet Processor:
	For every packet in the packet buffer
	
	If the packets final destination is not this node
		forward the packet (extract final dst, call
		forwardPacket(packet,final dst))
 	Else
		If ALL of the sibling packets are in the buffer
 				Insert all of the sibling packets into an
				array (if they aren't already)
 				and forward them to the external command
				buffer


 		Else
			Continue
External Command Procesor:
	For every packet array in the external command buffer (maybe we
	need a better name for this buffer)
		Call a function that reconstructs the payload from all of
		the packets
 		Send the payload to its respective function. (This would be
		an external command function controller
 		similar to what we have for terminal commands)
=end
 

#read in from config
$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil

#necessary variables
$routingTable = Hash.new
$timer = nil 
$nodeToPort = Hash.new
$nodeToSocket = Hash.new
$globalBuffer = Array.new 
$sendBuffer = Array.new 
$recvBuffer = Array.new 
$inPorts = Array.new
$outPorts = Array.new
$cmdLinBuffer = Array.new
$packetHash = Hash.new { |h1, k1| h1[k1] =  Hash.new { |h2, k2| h2[k2] =  Hash.new}} # packetHash[src][id][offset]

#Threads
$cmdLin = nil
$execute = nil
$server = nil
$processPax = nil

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
def edgeb(cmd)
	srcIp = cmd[0]
	dstIp = cmd[1]
	dst = cmd[2]
	#is this a good idea?
	if ($neighbor[dst])
		STDOUT.puts "Edge Already Exists"
		return
	end
	$nodeToSocket[dst] = TCPSocket.open(dstIp, $nodeToPort[dst])
	nextHop[dst] = dst
	cost[dst] = 1
	neighbor[dst] = true

	payload = [srcIp, $hostname].join(" ")

	send("EDBEBEXT", payload, dst)
end

def edgebExt(cmd)
	srcIp = cmd[0]
	node = cmd[1]

	nextHop[node] = node
	cost[node] = 1

	neighbor[node] = true
	#createConnection()
=begin
	If we decide to duplex or when we learn more about ruby tcp
	connections,
	then write the code for it here
=end


end

def dumptable(fileName)
	CSV.open(fileName, "wb") { |csv|
		$cost.each_key { |node|
			csv << [$hostname, node, $nextHop[node],
	   			$cost[node]]
		}
	}

end

# Close connections, empty buffers, kill threads
def shutdown(cmd)
	$cmdLin.kill
	$execute.kill
	$server.kill
	
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
	#puts "in main" #for debugging
	#start the thread that reads the command line input
	$cmdLin = Thread.new do
		getCmdLin()
	end
	#start the thread that executes command
	$execute = Thread.new do
		exTermCmd()
	end
=begin THIS IS CURRENTLY BROKEN MAKES PROGRAM HANG EVEN AFTER SHUTDOWN CALL
	#start the thread that will accept incoming connections and read
	#their input
	$server = Thread.new do
		server = TCPServer.new($port)
		loop do
			Thread.start(server.accept) do |client|
				#$inPorts << client
				#assuming reading from a client will give
				#full packet
				$recvBuffer << client.gets
			end
		end
	end
=end
	#make sure the program doesn't terminate prematurely
	$cmdLin.join
	$execute.join
	$server.join

end

def getCmdLin()
	while(line = STDIN.gets())

		line = line.strip()
		$cmdLinBuffer << line
	end
end

def exTermCmd()
	loop do
		if(!$cmdLinBuffer.empty?)
			line = $cmdLinBuffer.delete_at(0)
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
end

def setup(hostname, port, nodes, config)
#	puts "in setup"

	$hostname = hostname
	$port = port
	$timer = Timer.new
	parseConfig(config)
	parseNodes(nodes)

	# Initializes the hashes used for the routing tables
	nextHop = Hash.new("-")
	cost = Hash.new(1.0/0.0) #inf
	cost[$hostname] = 0;

	# Initializes the hashes used for neighbor checking and TCP object
	#connections
	neighbor = Hash.new
	tcpH = Hash.new

	# Initialized buffers
	$intComBuf = []
	$extComBuf = []
	$packetBuf = []

	# Unique ID used for each message. Incremented for every new message
	$nextMsgId = 0

	main()

end

# Reads the config file and stores its contents into respective variables
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

# Reads the nodes file and stores its node => port into $nodes hash 
def parseNodes(file)
	File.foreach(file){ |line|
		pieces = line.partition(",")
		$nodeToPort[pieces[0]] = pieces[2].to_i
	}
end

=begin
Send function for commands from this node's terminal NOT for commands from
other nodes
Fragments the payload, adds the IP header to each packet, and sends each
packet to the next node
=end
def send(cmd, payload, dst)
	fragments = payload.chars.to_a.each_slice($maxPayload).to_a.map{|s|
			s.to_s}
	packets = createPackets(cmd, fragments, dst)

	packets.each { |p|
		tcpSend(p, $nextHop[dst])
	}
end

# Appends header to each fragment
# ADD ALL OF THE HEADER INFO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
def createPackets(cmd, fragments, dst)
	packets = []

	fragments.each { |f|
		src = $hostname

		header = ["src="+src, "dst="+dst, "id="+id, "cmd="+cmd, "fragFlag="+fragFlag, "fragOffset="+fragOffset,
		"len="+len, "totLen="+totLen, "ttl="+ttl, "routingType="+routingType, "path="+path].join(",")

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
	#tcp = $tcpH[nextHop]$cmdLinBuffer << line
	tcp = $nodeToPort[nextHop]
	tcp.puts(p)
	# Code for actually sending the packet to the next node here. 
	# (If there is a tcp error, ignore it and let the timeout handle it)


end

=begin
	createConnection will take an array where the first element is
	the 
=end
def createConnection(cmd)
#	TCPSocket
end

# regex: /name=([^,])

def processPackets()
	loop do
		while (!recvBuffer.empty?)
			packet = recvBuffer[0]
			src = getHeaderVal(packet,"src")
			id = getHeaderVal(packet, "id").to_i
			offset = getHeaderVal(packet, "offset").to_i
			packetHash[src][id][offset] = packet
		end

		packetHash.each {|srcHash|
			srcHash.each {|idHash|
				sum = 0
				idHash.keys.sort.each {|k|
					packet = idHash[k]
					totLen = getHeaderVal(packet, "totLen").to_i
					sum = sum + getHeaderVal(packet, "len").to_i
				}

				if totLen == sum
					payload = reconstructPayload(idHash)
					$cmdLinBuffer << payload
			}
		}
	end
end

def getHeaderVal(packet,key)
	header = packet.splot(":")[0]
	return header.scan(/#{key}=([^,])/).flatten[0]
end
setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

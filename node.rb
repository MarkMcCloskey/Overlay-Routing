require 'thread'
require 'socket'
require 'csv'

# Properties for this node
$port = nil
$hostname = nil
$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil
$neighbor = Hash.new # Boolean hash. Returns true if a the key node is a neighbor
$timeout = 100000000000000000000000000
$nextMsgId = 0 # ID used for each unique message created in THIS node

# Routing Table hashes
# NOTE: Does not contain data for currently 
# 		unreachable nodes
$nextHop = Hash.new # nodeName => nodeName
$cost = Hash.new # nodeName => integer cost

# TCP hashes
$nodeToPort = Hash.new # Contains the port numbers of every node in our universe
$nodeToSocket = Hash.new # Outgoing sockets to other nodes

# Timer Object
$timer

# Buffers
$recvBuffer = Array.new 
$cmdLinBuffer = Array.new
$packetHash = Hash.new { |h1, k1| h1[k1] =  Hash.new { # Buffer used to make packet processing easier
			|h2, k2| h2[k2] =  Hash.new}} # packetHash[src][id][offset]

# Threads
$cmdLin
$execute
$server
$processPax
$serverConnections = Array.new # Array of INCOMING connection threads

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

	#create a connection with the new neighbor and save the 
	#socket in the hash
	$nodeToSocket[dst] = TCPSocket.open(dstIp, $nodeToPort[dst])

	$nextHop[dst] = dst
	$cost[dst] = 1
	$neighbor[dst] = true

	payload = [srcIp, $hostname].join(" ")

	send("EDBEBEXT", payload, dst)
end

def edgebExt(cmd)
	srcIp = cmd[0]
	node = cmd[1]


	$nextHop[node] = node
	$cost[node] = 1

	$neighbor[node] = true

	#open a connection between this node and the new neighbor
	#and save the socket in the hash
	$nodeToSocket[node] = TCPSocket.open(srcIp, $nodeToPort[node])

end

def dumptable(fileName)
=begin
	puts "in dumptable"
	puts fileName
	CSV.open(fileName, "w") { |csv|
		puts "got csv"
		$cost.each_key { |node|
			puts "node"
			csv << [$hostname, node, $nextHop[node],
	   			$cost[node]]
		}
		puts "done with node"
	}
	puts "done with dumptable"
=end
puts "in dumptable"
	puts fileName
	CSV.open(fileName, "w") do  |csv|
		puts "got csv"
		$cost.each_key do |node|
			puts "node"
			csv << [$hostname, node, $nextHop[node],
	   			$cost[node]]
	end
		puts "done with node"
end
	puts "done with dumptable"


end

# Close connections, empty buffers, kill threads
def shutdown(cmd)
	$cmdLin.kill
	#$execute.kill
	$server.kill
	$processPax.kill

	$serverConnections.each do |connection|
		connection.kill
	end

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

# --------------------- Threads --------------------- #

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
			when "EDGEBEXT"; edgebExt(args)
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
			when "nodeToPort";puts $nodeToPort
			when "curTime"; puts $timer.curTime
			when "startTime"; puts $timer.startTime
			when "runTime"; puts $timer.runTime
			when "port"; puts $port
			else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end
	end
end

def serverThread()
	server = TCPServer.new($port)
	loop do
		serverConnection = Thread.start(server.accept) do |client|
			#puts "in server accept"
			#assuming reading from a client will give
			#full packet
=begin
This is an infinite loop that will hang on select waiting for data from
the socket connection. If an even occurs it will check to see if the client
has disconnected, and if so close that socket. Otherwise it will read from
the socket
=end
			
			while 1
				incomingData = select(client, nil, nil)	
			
				for sock in incomingData[0]
					if sock.eof? then
						sock.close
					else
						$recvBuffer << 
						sock.recv($maxPayload)
					end
				end
			end
			
		end
=begin
This is for another idea where we keep all socket connections in one place
and then use select on all of them only reading from that ones that have
incoming data
$serverConnections << serverConnection
here's a good example
://www6.software.ibm.com/developerworks/education/l-rubysocks/l-rubysocks
-a4.pdf
=end
	end
end

def processPackets()
	loop do
		while (!recvBuffer.empty?)
			packet = recvBuffer[0]
			src = getHeaderVal(packet,"src")
			id = getHeaderVal(packet, "id").to_i
			offset = getHeaderVal(packet, "offset").to_i
			$packetHash[src][id][offset] = packet
		end

		$packetHash.each {|srcKey,srcHash|
			srcHash.each {|idKey, idHash|
				sum = 0
				idHash.keys.sort.each {|k|
					packet = idHash[k]
					totLen = getHeaderVal(packet, "totLen").to_i
					sum = sum + getHeaderVal(packet, "len").to_i
				}

				if totLen == sum
					payload = reconstructPayload(idHash)
					$cmdLinBuffer << payload
					packetHash[srcKey].delete(idKey)
				end
			}
		}
	end
end

# --------------------- Outgoing Packets Functions --------------------- #
=begin
Send function for commands from this node's terminal NOT for commands from
other nodes
Fragments the payload, adds the IP header to each packet, and sends each
packet to the next node
=end
def send(cmd, payload, dst)
	fragments = payload.chars.to_a.each_slice($maxPayload).to_a.map{|s|
			s.to_s}

	packets = createPackets(cmd, fragments, dst, payload.length)

	packets.each { |p|
		tcpSend(p, $nextHop[dst])
	}
end

# Appends header to each fragment
# ADD ALL OF THE HEADER INFO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
def createPackets(cmd, fragments, dst, totLen)
	packets = []
	fragOffset = 0
	fragments.each { |f|
		src = $hostname
		id = $nextMsgId
		fragFlag = 0 # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		len = f.length
		ttl = -1 # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		routingType = "packingSwitching" # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		path = "none"


		header = ["src="+src, "dst="+dst, "id="+id, "cmd="+cmd, "fragFlag="+fragFlag, "fragOffset="+fragOffset,
		"len="+len, "totLen="+totLen, "ttl="+ttl, "routingType="+routingType, "path="+path].join(",")

		p = header + ":" + f

		packets.push(p)

		fragOffset = fragOffset + len
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

	socket = $nodeToSocket[nextHop]
	#possible make sure this sends the full msg by checking num bytes
	#sent
	socket.send(packet)
	
end

# ---------------- Helper Functions ----------------- #
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

def getHeaderVal(packet,key)
	header = packet.splot(":")[0]
	return header.scan(/#{key}=([^,])/).flatten[0]
end


# --------------------- Main/Setup ----------------- #
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

	#start the thread that will accept incoming connections and read
	#their input
	$server = Thread.new do
		serverThread()
	end

	$processPax = Thread.new do
		processPackets()
	end

	#make sure the program doesn't terminate prematurely
	$cmdLin.join
	$execute.join
	$server.join
	$processPax.join

end

def setup(hostname, port, nodes, config)
#	puts "in setup"

	$hostname = hostname
	$port = port
	$timer = Timer.new
	parseConfig(config)
	parseNodes(nodes)

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

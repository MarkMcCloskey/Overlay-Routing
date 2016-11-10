require 'thread'
require 'socket'
require 'csv'
Thread::abort_on_exception = true

# Properties for this node
$port = nil
$hostname = nil
$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil
$neighbor = Hash.new # Boolean hash. Returns true if a the key node is a neighbor
$timeout = 100000000000000000000000000
$nextMsgId = 0 # ID used for each unique message created in THIS node
$packetSize = 100000
$TCPserver

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
$extCmdBuffer = Array.new
$packetHash = Hash.new { |h1, k1| h1[k1] =  Hash.new { # Buffer used to make packet processing easier
	|h2, k2| h2[k2] =  Hash.new}} # packetHash[src][id][offset]

# Threads
$cmdLin
$cmdExt
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
# Updates routing table, connections to the node, and send this node's information to 
# the other node so it could also establish a connection
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

	payload = ["EDGEBEXT",srcIp, $hostname].join(" ")

	send("EDGEBEXT", payload, dst)
end

# Recieves the external node information, updates the routing table,
# establishes a connection with that node
# Argument Format: <srcIp, nodeName>
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

# Dumps the routing table information into a CSV formatted file. 
# Row format: <srcNode, dstNode, nextHopNode, cost> 
def dumptable(args)
	fileName = args[0]
	CSV.open(fileName, "wb") { |csv|
		$cost.each_key { |node|
			csv << [$hostname, node, $nextHop[node],
	   $cost[node]]
		}
	}

end

# Close connections, empty buffers, kill threads
def shutdown(cmd)
	$server.kill # This is killing the server thread without gracefully kill the server first. Do we need to fix this?
	$processPax.kill

	# Might do a double shutdown if the other end already shutdown the connection. Do we need to fix this?
	$nodeToSocket.each_value do |socket| socket.shutdown end

	# Kills all serrver connection threads
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

# Command Line Input Thread
# Reads commands from the input and executes their
# respective functions
def getCmdLin()
	while(line = STDIN.gets())
		# Sleeps while the server thread is executing commands
		# This is done so the server can finish establishing an
		# incoming node connection before a command that requires
		# a connection with that node is executed.
		sleep 0.1 while $server.status != 'sleep'

		# Wait until an external command execution finishes before
		# executing a command line function. This avoids having
		# race conditions with the global variable properties
		if $cmdExt != nil 
			$cmdExt.join
		end

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

# External Command Execution thread.
# Executes commands querried by other nodes
def getCmdExt()
	# All commands are sent to a command buffer and this thread
	# executes every command in the buffer
	while(!$extCmdBuffer.empty?)

		line = $extCmdBuffer.delete_at(0)
		line = line.strip()

		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]

		case cmd
		when "EDGEBEXT"; edgebExt(args)
		else STDERR.puts "ERROR: INVALID COMMAND in getCmdExt\"#{cmd}\""
		end
	end
end

# Waits for incomming connection and starts a client thread for each
# connection that listens for packets
def serverThread()

	loop do
		#wait for a client to connect and when it does spawn
		#another thread to handle it

		serverConnection = Thread.start($TCPserver.accept) do |client|
			#add the socket to a global list of incoming socks
			$serverConnections << serverConnection
			clientThread(client)
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

# Listens for incoming packets from client nodes
def clientThread(client)
	loop do
		#wait for a connection to have data
		incomingData = select( [client] , nil, nil)

		#loop through the incoming sockets that
		#have data
		for sock in incomingData[0]
			#if the connection is over
			if sock.eof? then
				#close it
				sock.close
				$serverConnections.delete(serverConnection)
			
				#possibly delete information
				#from global variables

				serverConnection.kill # This kills this thread. 
				# Might be better to just return
			else
				#read what the connection
				#has and inputs it into a
				# packet buffer
				$recvBuffer << sock.gets
			end
		end
	end
end

# Process packets stored in the packer buffer
# Stores those packets into a nice triple hash that
# organized the packets by srcNode, messageId, and
# byte offset
def processPackets()
	totLen = nil
	# Flag used to check if packets have been added
	# into the triple hash
	checkPackets = false

	loop do
		# Empties the packet buffer and inserts them
		# into the hash
		while (!$recvBuffer.empty?)
			checkPackets = true

			packet = $recvBuffer.delete_at(0)

			src = getHeaderVal(packet,"src")
			id = getHeaderVal(packet, "id").to_i
			offset = getHeaderVal(packet, "offset").to_i

			$packetHash[src][id][offset] = packet
		end

		# Reads through every message hash and checks if
		# all packets have been received for that message.
		# If so, reconstructs the message, and pushes it
		# to the external command buffer
		if checkPackets
			# For each sourceNode hash
			$packetHash.each {|srcKey,srcHash|
				# For each message hash
				srcHash.each {|idKey, idHash|
					# Sum used to add each packets length
					# and verify if all packets have been
					# received by comparing the sum to
					# the total length of the message
					sum = 0
					totLen = nil
					# For each packet in offset order
					idHash.keys.sort.each {|k|
						packet = idHash[k]
						totLen = getHeaderVal(packet, "totLen").to_i
						sum = sum + getHeaderVal(packet, "len").to_i
					}

					if totLen != nil && totLen == sum
						msg = reconstructMsg(idHash)
						$extCmdBuffer << msg
						$packetHash[srcKey].delete(idKey)
					end
				}
			}
			checkPackets = false
		end

		# Exececute the new external commands
		$cmdExt = Thread.new do
			getCmdExt()
		end
		# The reason why I make a thread and wait for it here
		# is because that new thread can cause a race condition
		# for other threads and those other threads use the
		# global variable $cmdExt
		$cmdExt.join
	end
end

=begin
reconstructMsg will take a hashtable that contains offset -> packet
it will go through every packet extracting the payload and it will combine
them into a single message, returning that message
=end
def reconstructMsg(packetHash)
	msg = ""

=begin
the Hash contains one single message. The key is the offset value of that 
packet. Sort puts them in order of offset and then reassembles all the 
packets
=end
	packetHash.keys.sort.each { |offset| 
		msg += packetHash[offset].split(":")[1]
	}

	return msg
end

# --------------------- Outgoing Packets Functions --------------------- #
=begin
	Send function for commands from this node's terminal NOT for commands from
	other nodes
	Fragments the payload, adds the IP header to each packet, and sends each
	packet to the next node
=end
def send(cmd, msg, dst)
	# Divides the msg into fragments of at most maxPayLoad size
	fragments = msg.chars.to_a.each_slice($maxPayload).to_a.map{|s|
		s.join("")} #.to_s

	# From the fragments, it creates packets by adding headers
	# to each fragment
	packets = createPackets(cmd, fragments, dst, msg.length)

	# Send each packet to the next hop on its route to the
	# destination
	packets.each { |p|
		tcpSend(p, $nextHop[dst])
	}
end

# Appends header to each fragment
# Packet format: src=<src>,dst=<dst>,id=<id>,cmd=<cmd>,fragFlag=<fragFlag>,
# fragOffset=<fragOffset>,len=<len>,totLen=<totLen>,ttl=<ttl>,
# routingType=<routingType>,path=<path>
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
		path = "none" # MAKE THIS INTO VARIABLE FOR FUTURE PARTS

		# Creates header
		header = ["src="+src, "dst="+dst, "id="+id.to_s, "cmd="+cmd, "fragFlag="+fragFlag.to_s, "fragOffset="+fragOffset.to_s,
	    "len="+len.to_s, "totLen="+totLen.to_s, "ttl="+ttl.to_s, "routingType="+routingType, "path="+path].join(",")

	    # Appends header to fragment
		p = header + ":" + f

		# Adds the packet to the packet list
		packets.push(p)

		fragOffset = fragOffset + len
	}

	$nextMsgId = $nextMsgId + 1

	return packets
end

# Function called by packet buffer processors
# Not fully implemented. FIX FOR FUTURE PARTS
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
	socket.puts(packet)
end

# ---------------- Helper Functions ----------------- #

# Reads the config file and stores its contents into respective variables
def parseConfig(file)
	File.foreach(file){ |line|
		pieces = line.partition("=")
		if pieces[0] == "updateInterval"
			$updateInterval = pieces[2].to_i
		elsif pieces[0] == "maxPayload"
			$maxPayload = pieces[2].to_i
		elsif pieces[0] == "pingTimeout"
			$pingTimeout = pieces[2].to_i
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

# Returns the value of the specified field in the header
# of the given packet
def getHeaderVal(packet,field)
	header = packet.split(":")[0]
	return header.scan(/#{field}=([^,]*)/).flatten[0]
end


# --------------------- Main/Setup ----------------- #

# Starts the three main threads
def main()
	# start the thread that will accept incoming connections and read
	# their input
	$server = Thread.new do
		serverThread()
	end

	# start the thread that reads the command line input
	$cmdLin = Thread.new do
		getCmdLin()
	end


	$processPax = Thread.new do
		processPackets()
	end

	# make sure the program doesn't terminate prematurely
	$cmdLin.join
	$server.join
	$processPax.join

end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port.to_i
	$TCPserver = TCPServer.new($port)
	$timer = Timer.new
	parseConfig(config)
	parseNodes(nodes)

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

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
# Routing Table hashes
# NOTE: Does not contain data for currently 
# 		unreachable nodes
$nextHop = Hash.new # nodeName => nodeName
$cost = Hash.new # nodeName => integer cost
$TCPserver 
# TCP hashes
$nodeToPort = Hash.new # Contains the port numbers of every node in our universe
$nodeToSocket = Hash.new # Outgoing sockets to other nodes
$startReading = false
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
	puts "trying to connect"
	$nodeToSocket[dst] = TCPSocket.open(dstIp, $nodeToPort[dst])
	puts "tcp connected"
	puts $nodeToSocket[dst]
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
	#$cmdLin.kill
	#$server.kill
	#$processPax.kill
	$nodeToSocket.each_value do |val| val.shutdown end
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
	while(!$startReading)
	end
	while(line = STDIN.gets())
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

def getCmdExt() 
	while(!$extCmdBuffer.empty?)
		line = $extCmdBuffer.delete_at(0)
		line = line.strip()

		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]

		case cmd
		when "EDGEBEXT"; edgebExt(args)
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end
end

def serverThread()
	#start a server on this nodes port
	puts "in serverThread"
	#server = TCPServer.new($port)
	#puts "Server: " + server.to_s
		loop do
		#wait for a client to connect and when it does spawn
		#another thread to handle it
		$startReading = true

			serverConnection = Thread.start($TCPserver.accept) do |client|
			#add the socket to a global list of incoming socks
			puts "client connected" + client.to_s
			puts serverConnection
			$serverConnections << serverConnection
			

			loop do
				#wait for a connection to have data
				puts "waiting for data"
				incomingData = select( [client] , nil, nil)	
				puts "receiving data"
				puts incomingData[0]

				#loop through the incoming sockets that
				#have data
				for sock in incomingData[0]
					#if the connection is over
					if sock.eof? then
						#close it
						sock.close
						$serverConnections.delete(sock)
						#possibly delete information
						#from global variables

					else
						#read what the connection
                                                #has
					puts "putting data in buffer"
					$recvBuffer << sock.gets
					#$recvBuffer << sock.recv($packetSize)
					puts "data should be in the buff"
					puts $recvBuffer[-1]
					end
				end
			end

		end
	end




	#puts "in server accept"
	#assuming reading from a client will give
	#full packet
=begin
	This is an infinite loop that will hang on select waiting for data from
	the socket connection. If an even occurs it will check to see if the client
	has disconnected, and if so close that socket. Otherwise it will read from
	the socket
=end
=begin
			while 1
				incomingData = select(client, nil, nil)	

				for sock in incomingData[0]
					if sock.eof? then
						sock.close
					else
						$recvBuffer << sock.gets
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

def processPackets()
	loop do
		while (!$recvBuffer.empty?)
			packet = $recvBuffer[0]
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
					$extCmdBuffer << payload
					packetHash[srcKey].delete(idKey)
				end
			}
		}

		$cmdExt = Thread.new do
			getCmdExt()
		end
		$cmdExt.join
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
		s.to_s} #.to_s

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


		header = ["src="+src, "dst="+dst, "id="+id.to_s, "cmd="+cmd, "fragFlag="+fragFlag.to_s, "fragOffset="+fragOffset.to_s,
	    "len="+len.to_s, "totLen="+totLen.to_s, "ttl="+ttl.to_s, "routingType="+routingType, "path="+path].join(",")

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
	puts "trying to send"
	puts socket
	socket.send(packet, packet.size)
	puts "sent"
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

def getHeaderVal(packet,key)
	header = packet.splot(":")[0]
	return header.scan(/#{key}=([^,])/).flatten[0]
end


# --------------------- Main/Setup ----------------- #
def main()
	#start the thread that will accept incoming connections and read
	# their input
	$server = Thread.new do
		serverThread()
	end

	
	#puts "in main" #for debugging
	#start the thread that reads the command line input
	$cmdLin = Thread.new do
		getCmdLin()
	end


	$processPax = Thread.new do
		processPackets()
	end

	#make sure the program doesn't terminate prematurely
	$cmdLin.join
	$server.join
	$processPax.join

end

def setup(hostname, port, nodes, config)
	#	puts "in setup"

	$hostname = hostname
	$port = port
	$TCPserver = TCPServer.new($port)
	$timer = Timer.new
	parseConfig(config)
	parseNodes(nodes)

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

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
$nodeToPings = Hash.new #hash table to track pings goes from nodeName =>
		        #array
$traceRoute = Hash.new
DELTA_T = 0.5

# Routing Table hashes
# NOTE: Does not contain data for currently 
# 		unreachable nodes
$nextHop = Hash.new # nodeName => nodeName
$cost = Hash.new # nodeName => integer cost
$TCPserver 
# TCP hashes
$nodeToPort = Hash.new # Contains the port numbers of every node in our universe
$nodeToSocket = Hash.new # Outgoing sockets to other nodes

# Buffers
$recvBuffer = Array.new 
$extCmdBuffer = Array.new
$cmdLinBuffer = Array.new
$edgeBuffer = Array.new #buffer edgeu edged commands
$linkBuffer = Array.new #buffer link state packets
$packetHash = Hash.new { |h1, k1| h1[k1] =  Hash.new { # Buffer used to make packet processing easier
	|h2, k2| h2[k2] =  Hash.new}} # packetHash[src][id][offset]

# Threads
$execute
$cmdLin
$cmdExt
$server
$processPax
$serverConnections = Array.new # Array of INCOMING connection threads
$timer
$clock

class Timer
	DELTA_T = TENTH_SECOND = 0.1
	attr_accessor :startTime, :curTime
	def initialize
		@startTime = Time.new
		@curTime = @startTime
		@timeUpdater = Thread.new {
			loop do
				#sleep for some specified time then wake
				#and update timer
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
	#puts "trying to connect"
	sleep(1)
	$nodeToSocket[dst] = TCPSocket.open(dstIp, $nodeToPort[dst])
	#puts "tcp connected"
	#puts $nodeToSocket[dst]
	$nextHop[dst] = dst
	$cost[dst] = 1
	$neighbor[dst] = true

	payload = ["EDGEBEXT",srcIp, $hostname].join(" ")

	send("EDGEBEXT", payload, dst)
end

def edgebExt(cmd)
	#puts "edgebExt called"
	#puts cmd
	srcIp = cmd[0]
	node = cmd[1]


	$nextHop[node] = node
	$cost[node] = 1

	$neighbor[node] = true

	#open a connection between this node and the new neighbor
	#and save the socket in the hash
	#puts "edgebext about to open connection"
	$nodeToSocket[node] = TCPSocket.open(srcIp, $nodeToPort[node])
	#puts "edgebext opened connection"
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
	$timer.kill
	$nodeToSocket.each_value do |socket|
		begin 
			if !socket.shutdown? then
				socket.shutdown 
			end
		rescue
			1+1
		ensure 
			1+1
		end
	end

	$serverConnections.each do |connection|
		connection.kill
	end

	STDOUT.flush
	STDERR.flush

	exit(0)
end



# --------------------- Part 1 --------------------- # 
=begin
edged will be called whenever a connection between nodes should be 
destroyed. It will take the name of a destination node as input. It will 
then remove all edge information from this node to the destination node.
=end
def edged(cmd)
	#puts "EDGED called"
	dst = cmd[0] #get destination from args

	#shutdown and delete the socket connecting the nodes
	$nodeToSocket[dst].shutdown 
	$nodeToSocket.delete(dst)

	#remove destination from all the hashes tracking it
	$nextHop.delete(dst)
	$cost.delete(dst)
	$neighbor.delete(dst)
	#puts "EDGED done"
end

=begin
edgeU is the command given to a node to update the cost between itself and
a direct neighbor node. It will take as input the name of the neighbor and
the new cost. It will then update the cost to that neigbor, and notify the
neighbor to do the same.
=end
def edgeu(cmd)
	#check to make sure that none of the fields are missing
	#NOTE THIS DOESN'T CHECK TO MAKE SURE THEY ARE VALID
	#THIS IS IN THE SPEC!!!
	if(!(cmd == nil || cmd[0] == nil || cmd[1] == nil))
		dst = cmd[0]

		#check to make sure destination is a next hop neighbor
		#before continuing
		if($neighbor[dst])

			#grab the cost from the commands
			cost = cmd[1].to_i #might not need to_i

			#update cost in the hash
			$cost[dst] = cost

			#prep to send command to neighbor
			#payload = ["EDGEUEXT", $hostname, cost].join(" ")
			#send("EDGEUEXT",payload,dst)
		end
	end

end

=begin
edgeuExt is the function called when a node needs to notify a neighbor that
the cost between them has changed. It will take as input the name of the 
neighbor and the new cost. It will then update the cost to get to that 
neighbor.
=end
def edgeuExt(cmd)

	#get commands
	dst = cmd[0]
	cost = cmd[1].to_i

	#update cost hash with the new cost to get to the neighbor
	$cost[dst] = cost
end

def status()
	STDOUT.print "Name:" + " " + $hostname + " " + "Port:" + " " +
		$port.to_s + " " + "Neighbors:" + " "

	neighbors = $neighbor.keys
	neighbors = neighbors.join(",")
	STDOUT.print neighbors
	STDOUT.puts


end

=begin
timer that ensures link state packets are delivered and edge updates are
applied. At the correct times it will spawn new threads to take care of
this action.
=end
def keepTime
	time = 0
	loop do
		sleep(DELTA_T)
		time += DELTA_T
		#every update Interval flood link state packets
		if(time % $updateInterval == 0)
			Thread.new do
				linkStateUpdate
			end
		end

		#let link state packets settle for half an interval
		#then apply them to graph
		#then apply edged edgeu updates to graph
		if(time % (1.5*$updateInterval) == 0)
			Thread.new do
				emptyLinkBuffer
				emptyEdgeBuffer
			end
		end
	end
end

=begin
cycle through all the link state packets and apply them to the graph
=end
def emptyLinkBuffer
	while(!$linkBuffer.empty?)
		line = $linkBuffer.delete_at(0)
		line = line.strip()

		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]

		edgeuExt(args)
	end

end

=begin
cycle through all the edge updating commands and apply them to the graph
=end
def emptyEdgeBuffer
	while(!$edgeBuffer.empty?)
		line = $edgeBuffer.delete_at(0)
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGED";edged(args)
		when "EDGEU";edgeu(args)
		end


	end
end


def linkStateUpdate
	#puts "Flooding link-state updates now"
=begin PSUEDOCODE
	FOR EACH KEY IN $COST
	add KEY=COST to the string that goes in the payload

	FOR EACH KEY IN NEIGHBOR 
	SEND THE PAYLOAD 
=end

	payloadArr = []
	#puts "MY COSTKEYS FOR " + $hostname + ":" + $cost.to_s
	$cost.each { |node, cost| 
		payloadArr << node + "=" + cost.to_s 
	}
	#puts payloadArr

	$neighbor.each_key { |neighbor| 
		#puts "SENDING LINK STATE UPDATES TO " + neighbor
		payload = ["LSUEXT", payloadArr.join(","), $hostname].join(" ")
		send("LSUEXT", payload, neighbor)
	}

end

# Updates the node routing table if it finds a cheaper
# path
def linkStateUpdateExt(cmd)
	#puts "linkStateUpdateExt called"

	# This array should contain an array of "node=cost"
	senderCstStr = cmd[0].split(',')

	sender = cmd[1]

	# Hash extracted from the the payload
	# ie. if the payload has n1=14, this hash
	# will contain senderCstHash["n1"] = 14
	senderCstHash = Hash.new

	# Converts the payload string into the hash
	# explained above
	senderCstStr.each { |str|
		# tmp should contain ["n1", "14"]
		tmp = str.scan(/(.*)=(.*)/).flatten 
		senderCstHash[tmp[0]] = tmp[1].to_i
	}

	# Updates the hash table if needed
	senderCstHash.each { |dst, cst2Dst|
		# if the dst node is in the global hash,
		# check if the cost is cheaper. If it is,
		# update routing table
		if dst != $hostname 
			if $cost[dst] != nil
				if $cost[sender] + cst2Dst < $cost[dst] 
					$nextHop[dst] = sender
					$cost[dst] = $cost[sender] + cst2Dst
					#consider when path gets worse 
				elsif sender == $nextHop[dst]
					$cost[dst] = $cost[sender] + cst2Dst
				end
				# If the dst node is NOT in the global has,
				# add it to the routing table
			else 
				$cost[dst] = $cost[sender] + cst2Dst
				$nextHop[dst] = sender
			end
		end
	}
end

def dijkstras
	puts "Doing Dijkstras now"
end


# --------------------- Part 2 --------------------- # 
=begin

sendmsg will take an array of comands [destination message]. It will then
send the message to the destination. If the  destination is unreachable or 
the whole message cannot be sent, sendmsg will print an error.

=end
def sendmsg(cmd)
	STDOUT.puts "SENDMSG called"

	dst = cmd[0]		#pull destination
	msg = cmd[1]		#pull message
	puts "Destination: " + dst + " Message: " + msg


	payload = ["SENDMSGEXT", msg, $hostname].join(" ")
	puts "Payload: " + payload.to_s
	size = payload.length	#pull size to check when sending
	puts "Payload Size: " + size.to_s
=begin
	MARK, to ensure full message sent, make the send chain return
	the number of bytes sent then catch it here and do a check
=end

	send("SENDMSGEXT", payload, dst)
=begin PSUEDOCODE
	This should be relatively simple with our implementation.
	The only trouble should be timers.

	Get the dst and MSG from cmd array
	store MSG size
	build a payload using the arguments and send it.
	track amount sent and compare to msg size. if not the same print
	error
=end PSUEDOCODE
end

=begin

sendmsgExt is the receiving end of sendmsg. When a message comes in it 
prints it in the following format: SENDMSG: [SOURCE] --> [MESSAGE]

=end
def sendmsgExt(cmd)
	#MARK PROBABLY NEED TO BUFFER THESE AND ENSURE THE FULL MESSAGE HAS
	#ARRIVED BEFORE PRINTING MAYBE ADD TOTLEN
	#DOES OUR IMPLEMENTATION HANDLE THIS?
	
	STDOUT.puts "SENDMSGEXT called"
	msg = cmd[0]
	src = cmd[1]

	puts "SENDMSG: " + src + " --> " + msg

end
=begin
ping will take an array of arguments in the following order 
[destination #ofPingsToSend delay]. It will then send #ofPings to
destination with a delay in between each ping.

The packet a ping message will send looks like
PINGEXT dst sendTime src($hostname)
=end
def ping(cmd)
	#get inputi
	#puts "In Ping"
	#puts cmd
	dst = cmd[0]
	numPings = cmd[1].to_i
	delay = cmd[2].to_i
	
	#if the ping hash doesn't have an entry for dst, make one
	#if !$nodeToPings[dst].member?
	#	$nodeToPings[dst] = Array.new # array to hold ping timers
	#end
	#spawn a thread to keep track of time
	Thread.new(dst,numPings,delay) { |dst,numPings,delay|
		puts "In first thread"
		puts dst
		puts numPings
		puts delay
		
		
		time = 0
		sleepTime = delay/4
		pingCounter = 0
		#while we still have pings that need to be sent
		while pingCounter < numPings
			puts "pingCounter: " + pingCounter.to_s

			sleep sleepTime
			time += sleepTime
			
			#time to send a ping packet
			if(time % delay == 0)
				
				#spawn a thread the send the packet
				#may be unecessary but might help keep time
				#more accurately
				Thread.new(pingCounter,dst) { |pingCounter,dst|
					
				puts "In second thread"
				#puts pingCounter
				puts "Destination: " + dst
					
					#get time being sent
					#for comparison on return
					#to calculate round trip time
					sendTime = $clock.runTime
					#MARK comment this and it breaks
					sendTime = sendTime.round(3)	
					#send the command, ACK, sendtime,
					# Sequence #, destination and src
					#as the payload

					#src may not be necessary if we 
					#can parse from header
					payload = ["PINGEXT", "ACK=0",sendTime, pingCounter, dst, $hostname].join(" ")
				puts "Payload: " + payload.to_s	
					send("PINGEXT",payload,dst)

					#put the timer in the hash
					#$nodeToPing[dst] << $pingTimeout
					#start a timer decrementer thread?
				}
				
				pingCounter += 1
			end
		end
	}

=begin PSUEDOCODE
Thread.new do
	pingCounter = 0
	time = 0
	sendTime # grab time from Timer and put it in packet to be compared
		 # when the packet returns
	start timer to track delay
	while pingCounter < numPings
	sleep delay/2
	time += delay/2
	if(time%delay == 0)
	send ping
	pingCounter++
	end
	end
	end

=end PSUEDOCODE
end

=begin
pingExt will allow this node to handle the response from ping messages.

=end
def pingExt(cmd)
	#this line pulls the ack out of the payload and converts it to int
	#turns "ACK=X" -> x this int is needed for response decision logic
	
	
	ack = cmd[0].partition("=")[2].to_i
	puts"pingExt Called with Ack: " + ack.to_s + " " + "Command: " + cmd.to_s
	if(ack == 0)#send response to ping
		sendTime = cmd[1] #pull time sent from payload
		seqNum = cmd[2]	  #pull the sequence number from payload
		dst = cmd[4]	  #pull return destination from payload
	puts "In pingExt Ack=0"
	puts "Dst: " + dst + " seqNum: " + seqNum + " sendTime: " + sendTime
		
		payload = ["PINGEXT", "ACK=1", sendTime, seqNum,dst, $hostname].join(" ")
		send("PINGEXT",payload,dst)

	end
	if(ack == 1)#print ping messages
		#MARK NEED TO ADD LOGIC THAT CHECKS TO SEE IF PINGTIMEOUT
		#HAS EXPIRED BEFORE YOU DO THIS


		sendTime = cmd[1].to_f #pull sendTime and make it float
		seqNum = cmd[2]	       #pull seqNum
		dst = cmd[3]	       #pull the original destination
		rtt = $clock.runTime - sendTime
		rtt = rtt.round(3)
		puts seqNum + " " + dst + " " + rtt.to_s
	end

=begin PSUEDOCODE

if header contains ACK
then print receipt
else
reply to sender with PING ACK
=end PSUEDOCODE
end

=begin

traceroute will take an array of arguments in the form [destination].
It will lead to the printing of the hops taken to get from source node
to destination node. If a node takes too long to reply it will print a 
failure message for that node.
Output will be in the following form:
	For a successful reply -> [hopcount host-ID Time-to-node]
	For an unsuccessful reply -> timeout on hopcount
=end
def traceroute(cmd)
	STDOUT.puts "TRACEROUTE called"
	
	dst = cmd[0]			#pull destination from argument
	$traceRoute[dst] = Array.new	#create new route in hash
	$traceRoute[dst] << "0 " + $hostname  #ADD TIME add source to hash

	#create the payload. Payload will look like 
	#[COMMAND, source, destination, hopcount]
	#Source so that all nodes know where to send their return packets
	#destination so all nodes know where to forward traceroute
	#hopcount so each can increment and reply correctly
	#  **NEED TO ADD SOMETHING FOR TIME TO NODE**

	payload = ["TRACEROUTEEXT", $hostname, dst, 0].join(" ")
	send("TRACEROUTEEXT", payload, dst)
=begin PSUEDOCODE
	It may just be best for this traceroute to fire off the
	traceroute message and allow traceroute ext to handle most of the
	work

	maybe create an entry in a traceroute hash and allow tracertext
	to handle filling it and then printing it when it gets the final
	msg
=end PSUEDOCODE
end

=begin
tracerouteExt is the workhorse of the traceroute family. It is the control
logic for either stopping or forwarding the traceroute command. It is also 
in charge of replying to source or printing when done.
=end
def tracerouteExt(cmd)
	STDOUT.puts "TRACEROUTEEXT called"
	src = cmd[0]
	dst = cmd[1]
	hopCount = cmd[2].to_i
	#if the trace has reached it's destination
	if dst == $hostname
		hopCount += 1
		payload = ["TRACEROUTEEXT", src, dst, hopCount].join(" ")
		send("TRACEROUTEEXT", payload, src)
	#if the trace has made it's way back to the source
	elsif src == $hostname 
		$traceRoute[dst] << hopCount.to_s + " " + dst #ADDTIMESTUFF
		
		if $traceRoute.key?(dst)
			$traceRoute[dst].each { |str| puts str }
		end
		#THE TRACE SHOULD BE DONE NOW MAYBE DELETE THE ROUTE

	#otherwise it's an intermediate node
	else
		hopCount += 1 #increment hopCount
		
		#payload to be returned to sender
		payload = ["TRACEROUTEEXT", src, $hostname, hopCount].join(" ")
		send("TRACEROUTEEXT", payload, src)

		#payload to be forwarded to destination
		payload = ["TRACEROUTEEXT", src, dst, hopCount].join(" ")
		send("TRACEROUTEEXT", payload,dst)
	end
end

def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

# --------------------- Part 3 --------------------- # 
def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end

# --------------------- Threads --------------------- #

=begin
getCmdLin will receive any input from the command line and buffer it.
=end
def getCmdLin()
	while(line = STDIN.gets())
		$cmdLinBuffer << line
	end
end

=begin
executeCmdLin will take all the buffered commands from the command line
and execute them.
=end
def executeCmdLin()

	while(!$cmdLinBuffer.empty?)
		line = $cmdLinBuffer.delete_at(0)
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; $edgeBuffer << line #edged(args)
		when "EDGEU"; $edgeBuffer << line #edgeu(args)
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
		when "curTime"; puts $clock.curTime
		when "startTime"; puts $clock.startTime
		when "runTime"; puts $clock.runTime
		when "port"; puts $port
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end

	end
end

=begin
executeCmdExt will cycle through the commands that come from other nodes
and execute them.
=end
def executeCmdExt()
	while(!$extCmdBuffer.empty?)
		#	puts "inside getCmdExt"

		line = $extCmdBuffer.delete_at(0)
		line = line.strip()

		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]

		case cmd
		when "PINGEXT"; pingExt(args)
		when "EDGEBEXT"; edgebExt(args)
		when "EDGEUEXT"; $linkBuffer << line#edgeuExt(args)
		when "LSUEXT"; linkStateUpdateExt(args)
		when "SENDMSGEXT"; sendmsgExt(args)
		when "TRACEROUTEEXT"; tracerouteExt(args)
		else STDERR.puts "ERROR: INVALID COMMAND in getCmdExt\"#{cmd}\""
		end
	end
end

def serverThread()
	#start a server on this nodes port
	#puts "in serverThread"
	#server = TCPServer.new($port)
	#puts "Server: " + server.to_s
	loop do
		#wait for a client to connect and when it does spawn
		#another thread to handle it

		serverConnection = Thread.start($TCPserver.accept) do |client|
			#add the socket to a global list of incoming socks
			#puts "client connected" + client.to_s
			#puts serverConnection
			$serverConnections << serverConnection


			loop do
				#wait for a connection to have data
				#puts "waiting for data"
				incomingData = select( [client] , nil, nil)	
				#puts "receiving data"
				#puts incomingData[0]

				#loop through the incoming sockets that
				#have data
				for sock in incomingData[0]
					#if the connection is over
					if sock.eof? then
						#close it
						sock.close

						$serverConnections.delete(serverConnection)
						serverConnection.kill
						#possibly delete information
						#from global variables

					else
						#read what the connection
						#has
						#puts "putting data in buffer"
						$recvBuffer << sock.gets
						#$recvBuffer << sock.recv($packetSize)
						#puts "data should be in the buff"
						#puts $recvBuffer[-1]
					end
				end
			end

		end
	end


=begin
here's a good example
	://www6.software.ibm.com/developerworks/education/l-rubysocks/l-rubysocks
	-a4.pdf
=end
end

def processPackets()
	totLen = nil
	checkPackets = false
	#	loop do
	while (!$recvBuffer.empty?)
		checkPackets = true
		#puts "data in recv buffer"
		packet = $recvBuffer.delete_at(0)
		src = getHeaderVal(packet,"src")
		id = getHeaderVal(packet, "id").to_i
		offset = getHeaderVal(packet, "offset").to_i
		$packetHash[src][id][offset] = packet
		#puts "Src: "+ src 
		#puts "Id: " + id.to_s
		#puts "Offset: " + offset.to_s
		#puts "totLen: " + getHeaderVal(packet, "totLen") 
	end
	if checkPackets
		$packetHash.each {|srcKey,srcHash|
			srcHash.each {|idKey, idHash|
				sum = 0
				idHash.keys.sort.each {|k|
					#puts"inside id hash"
					packet = idHash[k]
					totLen = getHeaderVal(packet, "totLen").to_i
					sum = sum + getHeaderVal(packet, "len").to_i
				}

				if totLen!= nil && totLen == sum
					#puts "totLen"
					msg = reconstructMsg(idHash)
					$extCmdBuffer << msg
					$packetHash[srcKey].delete(idKey)

				end
			}
		}
		checkPackets = false
	end

	#		$cmdExt = Thread.new do
	#			getCmdExt()
	#		end
	#		$cmdExt.join
	#	end
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
	packetHash.keys.sort.each { |offset,val| 
		msg += packetHash[offset].split(":")[1]
	}

	return msg
end

# --------------------- Outgoing Packets Functions --------------------- #
=begin
Send function for commands from this node's terminal NOT for commands from
other nodes Fragments the payload, adds the IP header to each packet, and
sends each packet to the next node
=end
def send(cmd, msg, dst)
	fragments = msg.chars.to_a.each_slice($maxPayload).to_a.map{|s|
		s.join("")} #.to_s

	packets = createPackets(cmd, fragments, dst, msg.length)

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
	#puts "trying to send"
	#puts socket
	socket.puts(packet)
	#socket.send(packet, packet.size)
	#puts "sent"
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
	header = packet.split(":")[0]
	return header.scan(/#{key}=([^,]*)/).flatten[0]
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

=begin
	$processPax = Thread.new do
		processPackets()
	end
=end

	$execute = Thread.new do
		while 1
			processPackets
			executeCmdExt
			executeCmdLin
		end
	end

	$timer = Thread.new do
		keepTime()
	end

	#make sure the program doesn't terminate prematurely
	$cmdLin.join
	$server.join
	$processPax.join

end

def setup(hostname, port, nodes, config)
	#	puts "in setup"

	$hostname = hostname
	$port = port.to_i
	$TCPserver = TCPServer.new($port)
	$clock = Timer.new
	parseConfig(config)
	parseNodes(nodes)

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

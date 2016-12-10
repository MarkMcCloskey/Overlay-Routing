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
$ttl = 100		        #array
$traceRoute = Hash.new
$traceTimers = Hash.new
$sendMsgTimers = Hash.new
$circuit = Hash.new
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
	DELTA_T = TENTH_SECOND = 0.001 
	attr_accessor :startTime, :curTime
	def initialize
		@startTime = Time.new.to_f
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
	routingType = cmd[-2]
	path = cmd[-1]

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

	payload = ["EDGEBEXT",srcIp, $hostname, "jwan"].join(" ")

	send("EDGEBEXT", payload, dst, routingType, path)
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
	if $nodeToSocket[dst]
		$nodeToSocket[dst].shutdown
	end
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
	neighbors.sort!
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
	#make a deep copy of the array and then make a new link buffer
	#so that there's no additions to the arrays during clearing
	
	#arr = $linkBuffer.clone
	#$linkBuffer = Array.new

	#while(!$linkBuffer.empty?)
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
	#make a deep copy of the array and then make a new edgeBuffer so
	#that there's no additions to the array during clearing.
	#arr = $edgeBuffer.clone
	#$edgeBuffer = Array.new

	#while(!$edgeBuffer.empty?)
	while(!$edgeBuffer.empty?)
		line = $edgeBuffer.delete_at(0)
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		#puts "EDGEBUFF: " + cmd + args.to_s
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
		payload = ["LSUEXT", payloadArr.join(","), $hostname, "jwan"].join(" ")
		send("LSUEXT", payload, neighbor,"packetSwitching", "-1" )
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


# --------------------- Part 2 --------------------- # 
=begin

sendmsg will take an array of comands [destination message]. It will then
send the message to the destination. If the  destination is unreachable or 
the whole message cannot be sent, sendmsg will print an error.

=end
def sendmsg(cmd)
	STDOUT.puts "SENDMSG called with" + cmd.to_s

	dst = cmd[0]		#pull destination
	msg = cmd[1..-3].join(" ")            #pull message
	routingType = cmd[-2]
	path = cmd[-1]
	#puts "Destination: " + dst + " Message: " + msg

	#stuff the escape characters
	sendThis = "mork" + msg.to_s + "mork"

	payload = ["SENDMSGEXT","0", sendThis, $hostname,dst, "jwan"].join(" ")
	puts "Payload: " + payload.to_s
	size = payload.length	#pull size to check when sending
	#puts "Payload Size: " + size.to_s
=begin
	MARK, to ensure full message sent, make the send chain return
	the number of bytes sent then catch it here and do a check
=end

	send("SENDMSGEXT", payload, dst, routingType, path)
	
	$sendMsgTimers[dst] = $pingTimeout
	msgTracker(dst)
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

	STDOUT.puts "SENDMSGEXT called with " + cmd.to_s
	ack = cmd[0]
	msg = cmd[1]
	src = cmd[2]
	dst = cmd[3]

	#if it's the initial message it needs to be printed to the console
	if(ack == "0")

		#remove the stuffed chars
		msg = msg.gsub("mork","")
		
		#print necessary message
		STDOUT.puts "SENDMSG: " + src + " --> " + msg
		
		#build payload to send back to source
		#payload is [COMMAND, ACK, DONTCARE, SOURCE, STUFFEDCHAR]
		payload = ["SENDMSGEXT","1","junk",$hostname,"jwan"].join(" ")
		
		send("SENDMSGEXT",payload,dst,"packetSwitching","-1")
	
	#if another node is ACK'ing your message turn timer off
	elsif(ack == "1")
		$sendMsgTimers[src] = nil

	#just in case
	else
		STDOUT.puts "weirdness in sendMsgExt"
	end
end

=begin
msgTracker will take a nodename as a string representing the destination
of the message. It will then keep a timer for the message that was sent,
if the message arrives the timer will stop, if not it will print an error
message.
=end
def msgTracker(dst)

	
	sleepyTime = $pingTimeout/4 #generic time to sleep

	#new thread to do the tracking
	Thread.new(dst,sleepyTime) { |dst, sleepyTime|
	loop do	
		sleep sleepyTime
		
		
		timer = $sendMsgTimers[dst]
		
		#if timer is nil turn the timer off
		if timer == nil
			Thread.exit
		
		#if timer has expired print error message and turn timer
		#off
		elsif timer <= 0
			STDOUT.puts "SENDMSG ERROR: HOST UNREACHABLE"
			Thread.exit
		
		#otherwise decrease the timer
		else
			$sendMsgTimers[dst] = $sendMsgTimers[dst] - sleepyTime
		end
	end
	}

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
	##puts "PING CMD: " + cmd.to_s
	dst = cmd[0]
	numPings = cmd[1].to_i
	delay = cmd[2].to_i
	routingType = cmd[-2]
	path = cmd[-1]

	#if the ping hash doesn't have an entry for dst, make one
	if !$nodeToPings.key?(dst)
		$nodeToPings[dst] = Array.new # array to hold ping timers
	end
	#spawn a thread to keep track of time
	Thread.new(dst,numPings,delay) { |dst,numPings,delay|
		#puts "In first thread"
		#puts dst
		#puts numPings
		#puts delay

		#start a new thread that will go through and decrement all
		#ping timers.

		time = 0
		#sleepTime = delayi/4
		sleepTime = delay
		pingCounter = 0
		#while we still have pings that need to be sent
		while pingCounter < numPings
			#puts "pingCounter: " + pingCounter.to_s

			sleep sleepTime
			#time += sleepTime

			#time to send a ping packet
			#if(time % delay == 0)

			#spawn a thread the send the packet
			#may be unecessary but might help keep time
			#more accurately
			Thread.new(pingCounter,dst) { |pingCounter,dst|

				#puts "In second thread"
				#puts pingCounter
				#puts "Destination: " + dst

				#get time being sent
				#for comparison on return
				#to calculate round trip time
				sendTime = $clock.runTime
				#MARK comment this and it breaks
				sendTime = sendTime.round(3)	
				#send the command, ACK, sendtime,
				# Sequence #, destination and src
				#as the payload


				#get the array that's holding the ping
				#timeout counters and put a new one in
				#for the message about to be sent
				arr = $nodeToPings[dst]
				#puts "Sending pings arr: " + arr.to_s
				#puts "Pingtimeout: " + $pingTimeout.to_s
				arr[pingCounter] = $pingTimeout
				#puts arr.to_s
				limit = numPings * ($pingTimeout + delay)
				pingTracker(dst, limit)
				#src may not be necessary if we 
				#can parse from header

				payload = ["PINGEXT", "ACK=0",sendTime, pingCounter, dst, $hostname, "jwan"].join(" ")
				#puts "Payload: " + payload.to_s	
				send("PINGEXT",payload,dst,routingType,path)

				#put the timer in the hash
				#$nodeToPing[dst] << $pingTimeout
				#start a timer decrementer thread?
			}

			pingCounter += 1
			#end
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
	#puts"pingExt Called with Ack: " + ack.to_s + " " + "Command: " + cmd.to_s
	if(ack == 0)#send response to ping
		sendTime = cmd[1] #pull time sent from payload
		seqNum = cmd[2]	  #pull the sequence number from payload
		dst = cmd[4]	  #pull return destination from payload
		#puts "In pingExt Ack=0"
		#puts "Dst: " + dst + " seqNum: " + seqNum + " sendTime: " + sendTime

		payload = ["PINGEXT", "ACK=1", sendTime, seqNum,dst, $hostname, "jwan"].join(" ")
		send("PINGEXT",payload,dst, "packetSwitching", "-1")

	end
	if(ack == 1)#print ping messages
		#MARK NEED TO ADD LOGIC THAT CHECKS TO SEE IF PINGTIMEOUT
		#HAS EXPIRED BEFORE YOU DO THIS


		sendTime = cmd[1].to_f #pull sendTime and make it float
		seqNum = cmd[2]	       #pull seqNum
		dst = cmd[4]	       #pull the original destination

		#check to make sure the ping hasn't timed out already
		arr = $nodeToPings[dst]
		if(arr[seqNum.to_i] != nil )
			arr[seqNum.to_i] = nil
			rtt = $clock.runTime - sendTime
			rtt = rtt.round(3)
			puts seqNum + " " + dst + " " + rtt.to_s
		end

	end

=begin PSUEDOCODE

if header contains ACK
then print receipt
else
reply to sender with PING ACK
=end PSUEDOCODE
end

=begin
pingTracker takes a destination node and then starts tracking the timers
for the pings to that node. If a timer expires it will print and error
message.

=end
def pingTracker(dst,limit)
	#puts "Pingtracker called with dst" + dst.to_s
	#spawn thread to track timers	
	Thread.new(dst) { |dst|
		#semi arbitrary number cause why not
		num = $pingTimeout/4

		#suicide countdown for this thread
		timer = 0

		#sleep that magic number
		sleep num
		#puts "Pingtracker doing work"

		#thread getting closer to killing self
		timer = timer + num

		#get the array that corresponds to the stored ping timers
		arr = $nodeToPings[dst]
		#puts "arr: " + arr.to_s
		#if the arr contains timers
		if arr and timer < limit
			#go through and decrement
			arr.each_with_index { |clock, idx|
				#puts "Clock: " + clock.to_s
				if arr[idx] != nil
					arr[idx] =  clock - num
					if clock < 0 or clock == 0 
						STDOUT.puts "PING ERROR: HOST UNREACHABLE"
						arr[idx] = nil
					end 
				end
			}
		else
			#puts "pingtracker dying because " + timer.to_s
			#puts arr
			Thread.exit
		end


	}

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
	#STDOUT.puts "TRACEROUTE called with cmd: " + cmd.to_s

	dst = cmd[0]			#pull destination from argument
	routingType = cmd[-2]
	path = cmd[-1]
	
	$traceRoute[dst] = Array.new	#create new route in hash
	$traceRoute[dst] << "0 " + $hostname + " 0"  #ADD TIME add source to hash

	#make the next response a nil value for now. This is used for 
	#if statement logic in other parts of the program
	arr = $traceRoute[dst]
	arr[1] = nil

	#create the payload. Payload will look like 
	#[COMMAND, source, destination, hopcount forward]
	#Source so that all nodes know where to send their return packets
	#destination so all nodes know where to forward traceroute
	#hopcount so each can increment and reply correctly
	#forward tells intermediate nodes wether to reply and forward
	#or forward without reply

	time = $clock.curTime
	#puts "Send time: " + time.to_s
	payload = ["TRACEROUTEEXT", $hostname, dst, 0,time, "true", cmd[-1], "jwan"].join(" ")
	send("TRACEROUTEEXT", payload, dst, routingType, path)

	#start a timer for the next response
	$traceTimers[dst] = traceTimer(dst,1)

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
	#STDOUT.puts "TRACEROUTEEXT called with cmd: " + cmd.to_s
	src = cmd[0]
	dst = cmd[1]
	hopCount = cmd[2].to_i
	time = cmd[3]
	forward = cmd[4]
	routing = cmd[-2]
	circuitId = cmd[-1]

	#MARK YOU DID A DIRTY DIRTY HACK WITH THE FORWARD THING
	#CONSIDER BEING A DECENT HUMAN AND FIXING IT


	#if the trace has reached it's destination
	if dst == $hostname
		hopCount += 1
		#puts "Sent time: " + time
		#puts "Node time: " + $clock.curTime.to_s

		#time = $clock.curTime - time.to_f
		#puts "Time: " + time.to_s
		#time = time.abs
		#send the reply and stop forwarding	
		payload = ["TRACEROUTEEXT", src, dst, hopCount, time, $hostname, routing, "jwan"].join(" ")
		send("TRACEROUTEEXT", payload, src, "packetSwitching", "-1")

		#if the trace has made it's way back to the source
	elsif src == $hostname
		#puts "trying to add to hash with dst: " + dst

		arr = $traceRoute[dst]

		#if the route is still viable process incoming packets,
		#if not ignore them. This will pose problems if traceroute
		#is called, a timeoute occurs on the first trace, then 
		#a second traceroute is called while the original
		#traceroute packets are still in the network.

		if arr

			#timing stuff
			time = $clock.curTime - time.to_f#subtract curtime minus
			#original sent time

			time = time.abs/2 #take the absolute value of it and
			#divide by two. Assuming same time
			#trip each way

			time = time.round(4)#round to 4th digit passed zero
			#just to make it a little prettier

			time = time.to_s    #printable string

			arr[hopCount] =  hopCount.to_s + " " + forward + " " + time #ADDTIMESTUFF

			#deal with the timer thread
			$traceTimers[dst].terminate
			$traceTimers[dst] = traceTimer(dst,hopCount += 1 )

			if $traceRoute.key?(forward)
				$traceTimers[dst].terminate#kill timeout thread
				$traceRoute[forward].sort#sort based off hopcount
				$traceRoute[forward].each { |str| puts str }
				$traceRoute.delete(dst)
			end
		end
		#THE TRACE SHOULD BE DONE NOW MAYBE DELETE THE ROUTE

		#otherwise it's an intermediate node
		#and the trace isn't done yet
	elsif forward == "true"
		hopCount += 1 #increment hopCount

		#payload to be returned to sender
		payload = ["TRACEROUTEEXT", src, dst, hopCount, time, $hostname, routing, "jwan"].join(" ")
		send("TRACEROUTEEXT", payload, src, "packetSwitching", "-1")

		#payload to be forwarded to destination
		payload = ["TRACEROUTEEXT", src, dst, hopCount,time, forward, routing, "jwan"].join(" ")
		send("TRACEROUTEEXT", payload,dst, routing, circuitId)

		#now the trace is done so just send the cmd back
	else
		payload = ["TRACEROUTEEXT", src, dst, hopCount,time, forward, routing, "jwan" ].join( " ")
		send("TRACEROUTEEXT", payload ,src, "packetSwitching","-1")
	end
end

=begin
traceTimer will take dst that is the destination node as a string and
hopCount which is an integer telling what the next expected hop number is.
It will then start a countdown timer that allows the next node in the 
route to respond. If the node responds, the timer dies without needing to
take any action. If the timer expires this function handles writing the
error and printing the finished trace.
=end
def traceTimer(dst, hopCount)

	thread = Thread.new(dst, hopCount) { |dst, hopCount|
		#sleep for the timeout interval
		sleep $pingTimeout
		#pull array
		arr = $traceRoute[dst]

		#if someone has already put something in the array 
		#we no longer need to keep time on it
		#so kill the thread
		if arr[hopCount]
			Thread.exit
		else
			#since we've timed out the trace is done
			#print what we have and stop
			$traceRoute[dst].compact!#remove nil value at end
			$traceRoute[dst].sort#sort based off hopcount
			$traceRoute[dst].each { |str| puts str }
			STDOUT.puts "Timeout on " + hopCount.to_s

			#make array nil, this is used for logical checks
			$traceRoute[dst] = nil #elsewhere in the program

			#arr[hopCount] = "Timeout on " + hopCount.to_s
			Thread.exit
		end

	}
	thread#return the thread
end

=begin
ftp will take an array of arguments in the form 
[destination, filename, filepath] it will then transfer the filepath to the
destination node and store it with filename.
=end
def ftp(cmd)
	STDOUT.puts "FTP called with cmd: " + cmd.to_s
	dst = cmd[0] 		#get destination node
	file = cmd[1]   	#get filename
	path = cmd[2]   	#get filepath
	time = $clock.curTime.round(4)
	size = "IMPLEMENT SIZING"

	routingType = cmd[-2]
	circuitId = cmd[-1]
	#opens file, should read whole thing, and close it
	contents = IO.binread(file)
	#contents = File.read(file)
	size = contents.length
	#load payload with filename, path, and the contents of file, ACK
	#if this gets segmented will filename and filepath always
	#be contained in the message? they will be necessary to open
	#and store on the other end
	
	payload = ["FTPEXT",file,path, $hostname, "0", time,size, contents, "jwan"].join(" ")
	STDOUT.puts "Calling ftp with: " + payload.to_s
	#STDOUT.puts "done printing"
	send("FTPEXT",payload,dst, routingType, circuitId)

	#IF SUCCESSFUL SIZESENT = SIZEOFCONTENTS

end

=begin
ftpExt will take an array of arguments in the form
[filename, filepath, contents]. It will then save contents inside filename
to the filepath.
=end
def ftpExt(cmd)
	STDOUT.puts "FTPEXT called with cmd: " + cmd.to_s
	ack = cmd[3]

	if( ack == "0" )
		name = cmd[0]		#get file name
		path = cmd[1]		#get directory path
		src = cmd[2]            #get src name
		time = cmd[4]
		size = cmd[5]
		contents = cmd[6]	#get contents


		#if the directory doesn't already exist, create it
		if( !Dir.exists?(path) )
			Dir.mkdir(path)
		end
		Dir.chdir(path)		#change to the directory

		# Starts writing at the current end of file. Is this a good idea?
		# possible we should overwrite if already existing. Automated test
		# may fail a diff if we just add to end?

		#file = File.open(name,"w") # open, or create, a file for writing. 
		#file.puts(contents)
		#file.close		#close the file, cause good habits.

		IO.binwrite(name,contents)
		#get message to send back for timing
		payload = ["FTPEXT",name, $hostname, time,"1",size, "jwan" ].join(" ")
		#puts "Payload: " + payload.to_s
		send("FTPEXT",payload,src, "packetSwitching" , "-1")


		if(1)
			STDOUT.puts "FTP: " + src + " -- > " + path + "/" + name
		else
			STDOUT.put "FTP ERROR: " + src + " --> " + path + "/" + name 
		end

	elsif(ack == "1")
		file = cmd[0]
		dst = cmd[1]
		time = cmd[2]
		size = cmd[4]

		time = time.to_f
		size = size.to_f

		
		sendTime = $clock.curTime - time
		

		speed = size/sendTime
		sendTime = sendTime.round(4)
		speed = speed.to_i
		if(1)
			STDOUT.puts "FTP " + file + " --> " + dst + " in " + sendTime.to_s + " seconds" + " at " + speed.to_s + "Bps"
		else
			STDOUT.puts "FTP ERROR: " + file + " --> " + dst + " INTERRUPTED AFTER " + size
		end
	else
		STDOUT.puts "something went wrong"
	end

	end


# --------------------- Part 3 --------------------- # 
# JUAN ADDED: FUCK JUST REALZIZED THAT THE OUTPUT FOR CIRCUITM NEEDS TO HAVE
# EXTRA OUTPUT BESIDES THE REGULAR OUTPUT FROM THE OTHER REGULAR FUNCTIONS.
# REMEMBER TO ADD CIRCUITTYPE ARGUMENT TO EVERY PAYLOAD UNDER FUNCTIONS 
# UNDER CIRCUITM :(


# These functions for circtuiB contains two parts:
# 	1. Checks if the circuit is possible. 
# 	This would go through every node in the circuit.
# 	If it reaches the dst node, the dst node sends an ack 
# 	using packetSwithing (cause circuit is one way) to the src
#  	telling it is possible to build the circuit
# 	Else if it doesn't reach the dst and stops at a mid node,
# 	that mid node should send an ack back to the src telling it
# 	failed at the mid node.
#  	2. If from part 1, src receives a positive ack, then it builds
# 	the path by sending a string of all the nodes in the circuit and
# 	stripping them off as it goes through the circuit. 
# 	Else if it received a negative ack, then just output a ERROR message

# Sends the circuit path check message to the next node in the circuit.
# If there the next node is not a neigbhor then print the error message. 
def circuitB(cmd)
	circuitId = cmd[0]
	dst = cmd[1]
	circuit = cmd[2].split(",")
	fullCircuit = circuit.map do |e| e.dup end
	circuit.push(dst) 

	if $circuit.has_key?(circuitId)
		STDOUT.puts "CIRCUIT ERROR: " + $hostname + " -/-> " + dst + " FAILED AT " + $hostname	
		STDOUT.puts "This circuit error was due to one of the nodes already having a circuit with the same ID " + circuitId
		return
	end

	if circuit.empty?
		STDOUT.puts "DAFUQ. WHY DID YOU GIVE ME AN EMPTY CIRCUIT?"
		return
	end

	nextNode = circuit.delete_at(0)

	if $neighbor[nextNode]
		# Send payload
		payload = ["CIRCUITBEXTCHECK", circuitId, $hostname, dst, circuit.join(","), fullCircuit.join(","), "jwan"].join(" ")
		send("CIRCUITBEXTCHECK", payload, nextNode, "packetSwitching" , "-1")
	else
		STDOUT.puts "CIRCUIT ERROR: " + $hostname + " -/-> " + dst + " FAILED AT " + $hostname	
	end
end

# This is an intermediate node for circuitBCheck. 
def circuitBExtCheck(cmd)
	circuitId = cmd[0]
	src = cmd[1]
	dst = cmd[2]
	circuit = cmd[3].split(",")
	fullCircuit = cmd[4].split(",")

	if $circuit.has_key?(circuitId)
		payload = ["CIRCUITBEXTERROR", circuitId, src, dst, $hostname, "jwan"]
		send("CIRCUITBEXTCHECKERROR", payload, src, "packetSwitching" , "-1")
		STDOUT.puts "The following circuit error was due to one of the nodes already having a circuit with the same ID " + circuitId
		return
	end

	if circuit.empty? && dst == $hostname
		# Send positive acknowledgement back to src
		payload = ["CIRCUITBEXTCHECKPOS", circuitId, src, dst, fullCircuit.join(","), fullCircuit.join(","), "jwan"]
		send("CIRCUITBEXTCHECKPOS", payload, src, "packetSwitching" , "-1")
	elsif circuit.empty? && dst != $hostname
		STDOUT.puts "JUAN ERROR! WE FINISHED THE CIRCUIT PATH BUT SOMEONE DID NOT MANAGE TO END AT DST"
	else
		nextNode = circuit.delete_at(0)
		if $neighbor[nextNode]
			# Send payload
			payload = ["CIRCUITBEXTCHECK", circuitId, src, dst, circuit.join(","), fullCircuit.join(","), "jwan"].join(" ")
			send("CIRCUITBEXTCHECK", payload, nextNode, "packetSwitching" , "-1")
		else
			# Send a negative acknowledgement back to src with this node's name ($hostname)
			payload = ["CIRCUITBEXTERROR", circuitId, src, dst, $hostname, "jwan"]
			send("CIRCUITBEXTCHECKERROR", payload, src, "packetSwitching" , "-1")
		end
	end 
end

def circuitBExtError(cmd) 
	circuitId = cmd[0]
	src = cmd[1]
	dst = cmd[2]
	fNode = cmd[3]

	STDOUT.puts "CIRCUIT ERROR: " + src + " -/-> " + dst + " FAILED AT " + fNode
end

def circuitBExtCheckPos(cmd)
	circuitId = cmd[0]
	src = cmd[1]
	dst = cmd[2]
	circuit = cmd[3].split(",")
	fullCircuit = cmd[4].split(",")

	circuitTkn = 0

	circuit.push(dst)

	nextNode = circuit.delete_at(0)

	if $neighbor[nextNode]
		# Send payload
		$circuit[circuitId][circuitTkn] = nextNode
		payload = ["CIRCUITBEXTBUILD", circuitId, circuitTkn.to_s, $hostname, dst, circuit.join(","), fullCircuit.join(","), "jwan"].join(" ")
		send("CIRCUITBEXTCHECK", payload, nextNode, "packetSwitching" , "-1")
	else
		STDOUT.puts "SHIT! " + $hostname + " to " + nextNode + " was disconnected while processing circuitB."
		STDOUT.puts "Note: This does not delete the circuit hashes from previous nodes."
	end
end

def circuitBExtBuild(cmd)
	circuitId = cmd[0]
	circuitTkn = cmd[1].to_i + 1
	src = cmd[2]
	dst = cmd[3]
	circuit = cmd[4].split(",")
	fullCircuit = cmd[5].split(",")

	hops = fullCircuit.length
	
	if circuit.empty? && dst == $hostname
		#Send pos ack to src
		STDOUT.puts "CIRCUIT " + src + "/" + circuitId + " --> " + dst + " over " + hops.to_s
		payload = ["CIRCUITBEXTBUILDPOS", circuitId, src, dst, fullCircuit.join(","), "jwan"]
		send("CIRCUITBEXTCHECKPOS", payload, src, "packetSwitching" , "-1")
		return 
	end

	nextNode = circuit.delete_at(0)

	if $neighbor[nextNode]
		# Send payload
		$circuit[circuitId][circuitTkn] = nextNode
		payload = ["CIRCUITBEXTBUILD", circuitId, circuitTkn.to_s, $hostname, dst, circuit.join(","), "jwan"].join(" ")
		send("CIRCUITBEXTCHECK", payload, nextNode, "packetSwitching" , "-1")
	else
		STDOUT.puts "SHIT! " + $hostname + " to " + nextNode + " was disconnected while processing circuitB."
		STDOUT.puts "Note: This does not delete the circuit hashes from previous nodes."
	end

end

def circuitBExtBuildPos(cmd)
	circuitId = cmd[0]
	src = cmd[1]
	dst = cmd[2]
	fullCircuit = cmd[3]

	hops = fullCircuit.length

	if src != $hostname
		STDOUT.puts "WHERE DAFUQ AM I?"
		return
	end

	STDOUT.puts "CIRCUITB " + circuitId + " --> " + dst + " over " + hops.to_s
end

def circuitM(cmd)
	circuitId = cmd[0]
	line = cmd[1] # JUAN MAKE SURE THESE DONT HAVE QUOTATION MARKS

	line = line.strip()

	arr = line.split(' ') # CHANGE THIS TO THE REGEX !!!!!
	cmd = arr[0]
	args = arr[1..-1]
	args << "circuitSwitching"
	case cmd
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args)
		else STDERR.puts "ERROR: INVALID COMMAND in circuitM \"#{cmd}\""
	end
end

def circuitD(cmd)
	circuitId = cmd[0]


end

# --------------------- Threads --------------------- #

=begin
getCmdLin will receive any input from the command line and buffer it.
=end
def getCmdLin()
	while(line = STDIN.gets())
	#	puts "Std in line: " + line
		$cmdLinBuffer << line
	end
end

=begin
executeCmdLin will take all the buffered commands from the command line
and execute them.
=end
def executeCmdLin()
	#temp = $cmdLinBuffer.clone
	#$cmdLinBuffer = Array.new

	while(!$cmdLinBuffer.empty?)
		line = $cmdLinBuffer.delete_at(0)
		line = line.strip()
=begin		puts "executing line: " + line
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		args << "packetSwitching"
		puts "CmdLinCmd+Args" + cmd + args.to_s
=end
#=begin
		arr = line.scan(/(((mork)(.*)(mork))+|([\S]+))/)
		newArr = Array.new
		arr.map {|subArr| newArr << subArr[0] }
		cmd = newArr[0]
		args = newArr[1..-1]		
		args << "packetSwitching"
		args << "-1"
		#puts "CmdLinCmd+Args: "+ cmd + args.to_s
#=end
		
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
		when "hostname"; puts $hostname
		when "CIRCUITM"; circuitm(args)
		when "CIRCUITB"; circuitb(args)
		when "CIRCUITD"; circuitd(args)
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
	#temp = $extCmdBuffer.clone
	#$extCmdBuffer = Array.new

	while(!$extCmdBuffer.empty?)
		#	puts "inside getCmdExt"

		line = $extCmdBuffer.delete_at(0)
		line = line.strip()
=begin		
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-2]
		args << "packetSwitching"	
		puts "CmdLinExtCmd+Args: " + cmd + args.to_s
		
=end
#=begin
		arr = line.scan(/(((mork)(.*)(mork))+|([\S]+))/)
		newArr = Array.new
		arr.map {|subArr| newArr << subArr[0] }
		cmd = newArr[0]
		args = newArr[1..-1]
		#args << "packetSwitching"
		#puts "CmdLinExtCmd+Args: "cmd  + args.to_s
#=end
		case cmd
		when "PINGEXT"; pingExt(args)
		when "EDGEBEXT"; edgebExt(args)
		when "EDGEUEXT"; $linkBuffer << line#edgeuExt(args)
		when "LSUEXT"; linkStateUpdateExt(args)
		when "SENDMSGEXT"; sendmsgExt(args)
		when "TRACEROUTEEXT"; tracerouteExt(args)
		when "FTPEXT"; ftpExt(args)
		when "CIRCUITBEXTCHECK"; circuitBExtCheck(args)
		when "CIRCUITBEXTCHECKPOS"; circuitBExtCheckPos(args)
		when "CIRCUITBEXTERROR"; circuitBExtError(args)
		when "CIRCUITBEXTBUILD"; circuitBExtBuild(args)
		when "CIRCUITBEXTBUILDPOS"; circuitBExtBuildPos(args)
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
						#puts "Sock: " + sock.to_s
						#puts $nodeToSocket.to_s
						#MARK CALL EDGED
						#because a connection
						#no longer exist so the 
						#node is no longer 
						#a neighbor

						#	edged(nextHop)

						#nextHop = $nodeToSocket.key(sock)
						#$edgeBuffer << "EDGED " + nextHop 	
						sock.close

						$serverConnections.delete(serverConnection)
						serverConnection.kill
						#possibly delete information
						#from global variables

					else
						#read what the connection
						#has
						#puts "putting data in buffer"
						buffer = sock.gets("jwan")
					 	if buffer != nil	
						#puts "SERVERGOT: " + buffer
						#puts	
						$recvBuffer << buffer
						end
						#$recvBuffer << sock.gets()
						#str = sock.readlines(nil)
						#puts "In server str: " + str[0]
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
		#puts "data in recv buffer"
		packet = $recvBuffer.delete_at(0)
		#STDOUT.puts "Packet in process " + packet
		if ($hostname == getHeaderVal(packet,"dst") || getHeaderVal(packet, "cmd") == "TRACEROUTEEXT" || getHeaderVal(packet, "cmd") == "CIRCUITBEXTCHECK" || getHeaderVal(packet, "cmd") == "CIRCUITBEXTBUILD" )
			src = getHeaderVal(packet,"src")
			id = getHeaderVal(packet, "id").to_i
			offset = getHeaderVal(packet, "offset").to_i
			$packetHash[src][id][offset] = packet	
			checkPackets = true
		elsif packet.length != 0
			puts
			puts $hostname + " FORWARDING PACKET: " + packet.to_s
			puts
			forwardPacket(packet)

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
						#puts "MSG: " + msg.to_s
						#puts 
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
		msg += packetHash[offset].partition(":")[2]
	}

	return msg
end

# --------------------- Outgoing Packets Functions --------------------- #
=begin
Send function for commands from this node's terminal NOT for commands from
other nodes Fragments the payload, adds the IP header to each packet, and
sends each packet to the next node
=end
def send(cmd, msg, dst, routingType, circuitId)
	#puts "SEND ROUTING TYPE AND CIRCUIT: " + routingType + " " + circuitId  
	fragments = msg.chars.to_a.each_slice($maxPayload).to_a.map{|s|
		s.join("")} #.to_s


	packets = createPackets(cmd, fragments, dst, msg.length,routingType, circuitId )

	packets.each { |p|
		tcpSend(p, $nextHop[dst])
	}
end

# Appends header to each fragment
# ADD ALL OF THE HEADER INFO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
def createPackets(cmd, fragments, dst, totLen, routingType, circuitId)
	
	packets = []
	fragOffset = 0
	fragments.each { |f|
		src = $hostname
		id = $nextMsgId
		fragFlag = 0 # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		len = f.length
		#ttl = 100 # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		#	routingType = "packetSwitching" # MAKE THIS INTO VARIABLE FOR FUTURE PARTS
		path = "none"


		header = ["src="+src, "dst="+dst, "id="+id.to_s, "cmd="+cmd, "fragFlag="+fragFlag.to_s, "fragOffset="+fragOffset.to_s,
	    "len="+len.to_s, "totLen="+totLen.to_s, "ttl="+$ttl.to_s, "routingType="+routingType, "circuitId="+circuitId,"circuitTok="+"0"].join(",")

		p = header + ":" + f

		packets.push(p)

		fragOffset = fragOffset + len
	}

	$nextMsgId = $nextMsgId + 1

	return packets
end

# Function called by packet buffer processors
def forwardPacket(packet)
	#before you send possibly fragment
	#and nextHopwould be incorrect if it's a circuit
	#instead make it a variable and decide before this line
	#where it's going
	#STDOUT.puts packet
	#STDOUT.puts getHeaderVal(packet,"routingType")
	if packet == nil
		#puts "Nil packet in forwardPacket"

	elsif getHeaderVal(packet, "routingType") == "packetSwitching"
		dst = getHeaderVal(packet, "dst")
		if $nextHop[dst]
			nextDst = $nextHop[dst]
		end
	elsif getHeaderVal(packet, "routingType") == "circuitSwitching"
		circuitId = getHeaderVal(packet, "circuitId")
		circuitTkn = getHeaderVal(packet, "circuitTkn").to_i + 1

		nextDst = $circuit[circuitId][circuitTknt]

		header = packet.partition(":")[0]
		payload = packet.partition(":")[2]
		headerElements = header.split(",")
		headerElements[11] = "circuitTkn=" + circuitTkn.to_s
		headerElements = headerElements.join(",")
		packet = header + ":" + payload
	else
=begin
<<<<<<< HEAD
		puts "Routing type: " + getHeaderVal(packet, "routingType")
		STDOUT.puts "JUAN IMPLEMENT CIRCUITS"
=======
=end
		STDOUT.puts "SOMETHING WENT WRONG IN FORWARD PACKETS. HEADER VALUE FOR ROUTINGTYPE IS INCORRECT"
		
		STDOUT.puts getHeaderVal(packet, "routingType")
#>>>>>>> 3ac76e1edf19941a35092fe2e34169c4fec4edde
	end

	#modify TTL field, don't look, it's ugly
	if getHeaderVal(packet,"ttl").to_i - 1 > 0
		header = packet.partition(":")[0]
		payload = packet.partition(":")[2]
		headerElements = header.split(",")
		headerElements[8] = "ttl=" + (getHeaderVal(packet, "ttl").to_i - 1).to_s
		headerElements = headerElements.join(",")
		packet = header + ":" + payload
		tcpSend(packet, $nextHop[dst])
	else
		STDOUT.puts packet
		STDOUT.puts "A PACKET DIED IN " + $hostname
	end

end

# Function that actually calls the TCP function to send message
def tcpSend(packet, nextHop)

	socket = $nodeToSocket[nextHop]
	#puts "trying to send"
	#puts socket

	#attempt 
	if packet != nil && nextHop != nil#weird check that shouldn't be needed but is 
		#because of our code for some reason

		begin
			socket.puts(packet) #attempt to send

		rescue	#if sending fails the connection is broken and the neighbor
			#no longer exists
			#	edged(nextHop)
			STDOUT.puts "Node Died"
			$edgeBuffer << "EDGED EDGED " + nextHop 	
		end
		#socket.send(packet, packet.size)
		#puts "sent"
	end
end

# ---------------- Helper Functions ----------------- #
# Reads the config file and stores its contents into respective variables
def parseConfig(file)
	File.foreach(file){ |line|
		pieces = line.partition("=")
		if pieces[0] == "updateInterval"
			$updateInterval = pieces[2].to_f
		elsif pieces[0] == "maxPayload"
			$maxPayload = pieces[2].to_f
		elsif pieces[0] == "pingTimeout"
			$pingTimeout = pieces[2].to_f
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
	header = packet.partition(":")[0]
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

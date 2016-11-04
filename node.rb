$port = nil
$hostname = nil
$nodes = nil
$nextHop = nil
$cost = nil
$tcpH = nil
$neighbor = nil
$updateInteveral = nil
$maxPayload = nil
$pingTimeOut = nil
$timeout = nil



# --------------------- Part 0 --------------------- # 

def edgeb(cmd)
	srcIp = cmd[0]
	dstIp = cmd[1]
	dst = cmd[2]

	if (neigbor[dst])
		STDOUT.puts "Edge Already Exists"
		return

	tcpH[$hostname] = connect(srcIp, dstIp)
	nextHop[dst] = dst
	cost[dst] = 1

	send("edgeb", [srcIp, $hostname, $port)
end

def dumptable(cmd)
	STDOUT.puts "DUMPTABLE: not implemented"
end

def shutdown(cmd)
	STDOUT.puts "SHUTDOWN: not implemented"
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

	#set up ports, server, buffers
	readNodes(nodes)
	readConfig(config)

	nextHop = Hash.new("-")

	cost = Hash.new(1.0/0.0) #inf
	cost[$hostname] = 0;

	neighbor = Hash.new
	tcpH = Hash.new

	listen()

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])






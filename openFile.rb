class MyFile

	def open(fileName, message)
		File.open(fileName, "w"){ |file| file.puts message }
	end

end


module Verification
	def Verification.verify input
		md5 = Digest::MD5.hexdigest("9WvcZ9hX" + input + "KF7L4luQ").upcase.split(//)
		chars = ["A", "B", "C", "D", "E", "F"]
		nums = []
		lastPos = md5[31].to_i
		result = ""

		for i in 0..9
			pos = md5[i].to_i

			if pos == 0
				pos = lastPos ** (i % 4)
			elsif (pos % 4) == 0
				pos = pos * lastPos + i
			elsif (pos % 3) == 0
				pos = pos ** (i % 4)
			elsif (pos % 2) == 0
				pos = pos * i + pos
			end

			pos = (pos > 31) ? (pos % 32) : pos
			curChar = md5[31 - pos]
			curNum = curChar.to_i

			if nums.include? curNum
				if curNum == 0
					curChar = chars[pos % 6]
				else
					curChar = (pos % 10).to_s
				end
				curNum = curChar.to_i
			end

			nums << curNum
			result << curChar
			lastPos = pos
		end

		return result
	end

	def Verification.uncrap str
		str.to_s.gsub(/[^A-Za-z0-9_\-]/, "")
	end

	def Verification.random_string len
		chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
		str = ""
		1.upto(len) do |i|
			str << chars[rand(chars.size-1)]
		end
		return str
	end

  # TODO: rikki?
	def Verification.contain params, filter
		(params.instance_of?(Array) ? params : params.keys).each do |key|
			return false unless filter.include? key.to_sym
		end
		return true
	end
end
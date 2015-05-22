module Verification
	def Verification.uncrap str
		str.to_s.gsub(/[^A-Za-z0-9_\-]/, "")
	end

	def Verification.match_addr str
		str.to_s.match(/(([0-9]{1,3}\.){3}[0-9]{1,3}):?([0-9]{0,5})/)[0]
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
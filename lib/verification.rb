module Verification
  def self.verify(input)
    md5 = Digest::MD5.hexdigest("9WvcZ9hX" + input + "KF7L4luQ").upcase.split(//)
    chars = %w[A B C D E F]
    nums = []
    last_pos = md5[31].to_i
    result = ""

    (0..9).each do |i|
      pos = md5[i].to_i

      if pos == 0
        pos = last_pos**(i % 4)
      elsif (pos % 4) == 0
        pos = pos * last_pos + i
      elsif (pos % 3) == 0
        pos **= (i % 4)
      elsif pos.even?
        pos = pos * i + pos
      end

      pos = (pos > 31) ? (pos % 32) : pos
      cur_char = md5[31 - pos]
      cur_num = cur_char.to_i

      if nums.include? cur_num
        if cur_num == 0
          cur_char = chars[pos % 6]
        else
          cur_char = (pos % 10).to_s
        end
        cur_num = cur_char.to_i
      end

      nums << cur_num
      result << cur_char
      last_pos = pos
    end

    result
  end

  def self.uncrap(str)
    str.to_s.gsub(/[^A-Za-z0-9_\-]/, "")
  end

  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    str = ""
    1.upto(len) do
      str << chars[rand(chars.size - 1)]
    end
    str
  end

  # TODO: rikki?
  def self.contain(params, filter)
    params.instance_of?(Array) ? (filter - params).empty? : filter.all? { |s| params.key? s }
  end
end

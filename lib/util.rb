class Util
  def self.secure_random_between(start_inclusive, end_exclusive)
    range = end_exclusive - start_inclusive

    start_inclusive + SecureRandom.random_number(range)
  end

  def self.secure_compare(a, b)
    return false unless a.bytesize == b.bytesize

    l = a.unpack "C#{a.bytesize}"

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end
end
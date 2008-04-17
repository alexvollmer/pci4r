class Time
  # :nodoc:
  def minutes_of_day
    self.hour * 60 + self.min
  end
end

module Optimization
  
  def self.random_optimize(domain, &costf)
    best = 999_999_999
    bestr = nil
    1000.times do |i|
      r = (0...domain.size).map do |i|
        rand(domain[i][1] - domain[i][0]) + domain[i][0]
      end
      cost = costf.call(r)

      if cost < best
        best = cost
        bestr = r
      end
      r
    end
    bestr
  end
end
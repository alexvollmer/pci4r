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

  def self.hill_climb(domain, &costf)
    sol = (0...domain.size).map do |i|
      rand(domain[i][1] - domain[i][0]) + domain[i][0]
    end

    while true do
      neighbors = []
      (0...domain.size).each do |j|
        if sol[j] > domain[j][0]
          neighbors << sol.dup
          neighbors.last[j] += 1
        end
        if sol[j] < domain[j][1]
          neighbors << sol.dup
          neighbors.last[j] -= 1
        end
      end

      current = costf.call(sol)
      best = current
      (0...neighbors.size).each do |j|
        cost = costf.call(neighbors[j])
        if cost < best
          best = cost
          sol = neighbors[j]
        end
      end

      break if best == current
    end

    sol
  end
end
##
# This module provides a number of methods that help pick the
# best solution from a given domain and cost function. Each function
# takes an array of domain pairs, where the first number in the pair
# is the minimum of the domain and the second number is the maximum.
# The total number of items in the domain array should match the
# number of items you want in the solution to be computed.
#
# Additionally, each function will also yield a randomly-generated
# solution to a block from which a problem-specific cost should be
# calculated. Solutions are arrays of values within the domain values
# given. What these values are mean are specific to your problem-domain,
# but are limited to the given domain values.
#
# ==Example
#   # a totally dumb cost function
#   def compute_my_cost(sol)
#     total = 0
#     sol.each do { |x| total += x }
#     total
#   end
#
#   # domain is ten total values, each with a possible solution between 0 and 9
#   domain = [[0, 9]] * 10
#
#   solution = Optimization.random_optimize(domain) do |sol|
#     compute_my_cost(sol)
#   end
module Optimization

  ##
  # The most naive of the optimization solutions presented here.
  # This simply generates one thousand random solutions and returns
  # the cheapest according to the cost computed by the given block.
  # === options
  # * <tt>domain</tt> - The domain array of acceptable solution values
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
    end
    bestr
  end

  ##
  # Returns a solution (whose cost is calculated by a given block)
  # that is calculated by first creating a random solution, then
  # systematically applies the cost function to each neighboring
  # solution, finally returning the best of the lot.
  # === options
  # * <tt>domain</tt> - The domain array of acceptable solution values
  def self.hill_climb(domain, &costf)
    sol = (0...domain.size).map do |i|
      rand(domain[i][1] - domain[i][0]) + domain[i][0]
    end

    while true do
      neighbors = []
      (0...domain.size).each do |j|
        if sol[j] > domain[j][0]
          neighbors << sol.dup
          neighbors.last[j] -= 1
        end
        if sol[j] < domain[j][1]
          neighbors << sol.dup
          neighbors.last[j] += 1
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

  ##
  # Optimization based on a simulation of "annealing". The idea is that
  # during the process of choosing from random solutions, there is a
  # decreasing probability that the function will choose a more expensive
  # solution. The idea is to avoid local minima while casting about for
  # the best solution.
  # === options
  # * <tt>domain</tt> - The array of acceptable solution values
  # * <tt>temp</tt> - The starting "temperature" value. Solutions are computed until we've cooled down from this temp
  # * <tt>cool</tt> - The amount of cooling per iteration
  # * <tt>step</tt> - The amount to shift a single element in the solution
  def self.annealing(domain, temp=10_000, cool=0.95, step=1, &costf)
    vec = (0...domain.size).map do |i|
      (rand(domain[i][1] - domain[i][0]) + domain[i][0]).to_f
    end

    while temp > 0.1 do
      i = rand(domain.size - 1)
      dir = rand(step * 2) - step
      vecb = vec.dup
      vecb[i] += dir
      if vecb[i] < domain[i][0]
        vecb[i] = domain[i][0]
      elsif vecb[i] > domain[i][1]
        vecb[i] = domain[i][1]
      end

      ea = costf.call(vec)
      eb = costf.call(vecb)
      p = Math.exp(-eb - ea) / temp

      vec = vecb if (eb < ea or rand < p)

      temp = temp * cool
    end

    vec
  end
end
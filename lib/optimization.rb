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
  def self.random_optimize(domain)
    raise "You must provide a block to calculate cost" unless block_given?
    best = 999_999_999
    bestr = nil
    1000.times do |i|
      r = (0...domain.size).map do |i|
        rand(domain[i][1] - domain[i][0]) + domain[i][0]
      end
      cost = yield(r)

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
  def self.hill_climb(domain)
    raise "You must provide a block to calculate cost" unless block_given?

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

      current = yield(sol)
      best = current
      (0...neighbors.size).each do |j|
        cost = yield(neighbors[j])
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
  def self.annealing(domain, temp=10_000, cool=0.95, step=1)
    raise "You must provide a block to calculate cost" unless block_given?

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

      ea = yield(vec)
      eb = yield(vecb)
      p = Math.exp(-eb - ea) / temp

      vec = vecb if (eb < ea or rand < p)

      temp = temp * cool
    end

    vec
  end

  ##
  # This function returns a solution using the cost calculated by the
  # given block. This function uses genetic mutation to find the best
  # solution.
  # ===options
  # * <tt>domain</tt> - The array of acceptable solution values
  # * <tt>pop_size</tt> - The size of the population from which to apply Darwin's theory
  # * <tt>step</tt> - How far to mutate one value in the solution
  # * <tt>mut_prod</tt> - The probability that a new member will mutate (rather than crossover)
  # * <tt>elite</tt> - The percentage of a generation considered 'elite'
  # * <tt>iters</tt> - The number of genetic iterations to perform
  def self.genetic(domain, pop_size=50, step=1, mut_prod=0.2, elite=0.2, iters=100)
    raise "You must provide a cost function as a block" unless block_given?
    # build the initial population
    population = (0...pop_size).map do |i|
      (0...domain.size).map { |r| rand(domain[r][1] - domain[r][0]) + domain[r][0] }
    end

    # the number of winners for each generation
    top_elite = (elite * pop_size).to_i

    # main loop
    scores = []
    iters.times do |i|
      scores = population.map { |p| [yield(p), p] }.sort
      ranked = scores.map { |s| s[1] }

      # the pure winners
      population = ranked[0..top_elite]

      # add mutated and bred forms of the winners
      while population.size < pop_size
        if rand < mut_prod # mutate!
          c = rand(top_elite)
          population << mutate(ranked[c], domain, step)
        else # crossover!
          c1 = rand(top_elite)
          c2 = rand(top_elite)
          population << crossover(ranked[c1], ranked[c2], domain)
        end
      end
    end

    scores[0][1] # the winner!
  end

  private
  # :no-doc:
  def self.crossover(r1, r2, domain)
    i = rand(domain.size - 1) + 1
    r1[0...i] + r2[i..-1]
  end

  # :no-doc:
  def self.mutate(vec, domain, step)
    i = rand(vec.size)
    if rand < 0.5 and vec[i] > domain[i][0]
      vec2 = vec.dup
      vec2[i] =- step
      vec2
    elsif vec[i] < domain[i][1]
      vec2 = vec.dup
      vec2[i] += step
      vec2
    else
      vec
    end
  end
end
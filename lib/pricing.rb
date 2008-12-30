require "ostruct"

##
# Code based on Chapter 8: Building Price Models
#
# All methods taking a parameter named <tt>data</tt> expect
# it to be an array of objects that respond to the following
# methods:
#  * <tt>input</tt> - An array of one or more numeric values
#  * <tt>result</tt> - The resulting price.
# See <tt>make_data</tt> for a convenient way to create data
# nodes.
module Pricing

  class << self
    ##
    # Creates a single data element that is compatible with the
    # methods in this module. The returned object is an
    # <tt>OpenStruct</tt> with the fields <tt>input</tt> and
    # <tt>result</tt>.
    def make_data(result, *input)
      OpenStruct.new(:result => result, :input => input)
    end

    ##
    # Calculates the Euclidean distance between two data vectors.
    # The value is computed as the sum of the square of differences.
    def euclidean(v1, v2)
      d = 0.0
      v1.each_with_index do |e, i|
        d += (v1[i] - v2[i]) ** 2
      end
      Math.sqrt(d)
    end

    ##
    # Calculates the total distances between given vector and
    # every other vector in the dataset
    def distances(data, vector)
      distances = []
      data.each_with_index do |d, i|
        v2 = d.input
        distances << [euclidean(vector, v2), i]
      end
      distances.sort
    end

    ##
    # Averages the distances between the given vector and
    # k-nearest neighbors (defaults to 3)
    def knn_estimate(data, vector, k=3)
      dlist = distances(data, vector)
      avg = 0.0

      dlist.each_with_index do |e, i|
        idx = dlist[i][1]
        avg += data[idx].result
      end
      avg / k
    end

    ##
    # Calculates a weighted average of distances between
    # the given vector and k-nearest neighbors in the
    # <tt>data</tt>. The given block will be given the distance
    # and is expected to return a weight. See the <tt>Weights</tt>
    # sub-module for available weighting functions.
    def weighted_knn_estimate(data, vector, k=5, &block)
      distances = distances(data, vector)
      avg = 0.0
      total_weight = 0.0
      k.times do |i|
        dist, idx = distances[i]
        weight = block.call(dist)
        avg += weight * data[idx].result
        total_weight += weight
      end
      avg / total_weight
    end
  end

  ##
  # This sub-module contains several functions related to
  # weighting averages in the <tt>weighted_knn_estimate</tt>
  # method. Each returns a <tt>Proc</tt> instance that will
  # perform the calculation.
  module Weights

    ##
    # Returns a <tt>Proc</tt> that simply inverts the distance,
    # ensuring that the value never dips below the given
    # <tt>const</tt> value.
    def self.inverse(dist, num=1.0, const=0.1)
      num / (dist  + const)
    end

    ##
    # Returns a <tt>Proc</tt> that subtracts the distance value
    # from the given <tt>const</tt>.
    def self.subtract_weight(dist, const=1.0)
      dist > const ? 0 : const - dist
    end

    ##
    # Returns a <tt>Proc</tt> that places the given distance in
    # a Gaussian (bell) curve. The slope of the curve is affected
    # by the <tt>sigma</tt> parameter.
    def self.gaussian(dist, sigma=10.0)
      Math::E ** (-dist  ** 2 / (2 * sigma ** 2))
    end
  end
end

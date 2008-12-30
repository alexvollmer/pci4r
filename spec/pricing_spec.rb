require File.join(File.dirname(__FILE__), "../lib/pricing")

# TODO: these specs are pretty lame...

describe Pricing, 'weighted_knn_estimate' do
  it 'should return different values for different weighting functions' do
    data = (1..10).to_a.map { |x| Pricing.make_data(10 + x, x, x + 1) }
    vector = [5, 6]
    e1 = Pricing.weighted_knn_estimate(data, vector, 5) do |dist|
      Pricing::Weights.inverse(dist)
    end
    e2 = Pricing.weighted_knn_estimate(data, vector, 5) do |dist|
      Pricing::Weights.subtract_weight(dist, 9)
    end
    e3 = Pricing.weighted_knn_estimate(data, vector, 5) do |dist|
      Pricing::Weights.gaussian(dist)
    end

    e1.should_not == e2
    e2.should_not == e3
    e3.should_not == e1
  end
end

describe Pricing::Weights do

  describe 'inverse' do
    it 'should return different values for num values' do
      Pricing::Weights.inverse(5).
        should_not == Pricing::Weights.inverse(5, 2.0)
    end

    it 'should return different values for different const values' do
      Pricing::Weights.inverse(5).
        should_not == Pricing::Weights.inverse(5, 1.0, 0.2)
    end
  end

  describe 'subtract_weight' do
    it 'should return different values for different const values' do
      Pricing::Weights.subtract_weight(1).
        should_not == Pricing::Weights.subtract_weight(1, 2.0)
    end
  end

  describe 'gaussian' do
    it 'should return different values for different sigma values' do
      Pricing::Weights.gaussian(5).
        should_not == Pricing::Weights.gaussian(5, 11.0)
    end
  end

end

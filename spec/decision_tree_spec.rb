require File.join(File.dirname(__FILE__), "/../lib/decision_tree")

describe "DecisionTree" do
  before(:each) do
    @data = [
      ['slashdot','USA','yes',18,'None'], 
      ['google','France','yes',23,'Premium'], 
      ['digg','USA','yes',24,'Basic'], 
      ['kiwitobes','France','yes',23,'Basic'], 
      ['google','UK','no',21,'Premium'], 
      ['(direct)','New Zealand','no',12,'None'], 
      ['(direct)','UK','no',21,'Basic'], 
      ['google','USA','no',24,'Premium'], 
      ['slashdot','France','yes',19,'None'], 
      ['digg','USA','no',18,'None'], 
      ['google','UK','no',18,'None'], 
      ['kiwitobes','UK','no',19,'None'], 
      ['digg','New Zealand','yes',12,'Basic'], 
      ['slashdot','UK','no',21,'None'], 
      ['google','UK','yes',18,'Basic'], 
      ['kiwitobes','France','yes',19,'Basic']
    ]
  end

  describe "self.divide" do
    it "should divide correctly on a String value" do
      result = DecisionTree.divide(@data, 2, 'yes')
      result.size.should == 2
      matching = result.first.map { |m| m[0] }
      %w[slashdot google digg kiwitobes].each do |site|
        matching.should be_member(site)
      end
      
      not_matching = result.last.map { |m| m[0] }
      %w[google (direct) digg kiwitobes].each do |site|
        not_matching.should be_member(site)
      end
    end
  end

  describe "gini_impurity" do
    it "should return zero for a uniform set" do
      DecisionTree.gini_impurity({"foo" => 1}).should == 0
    end

    it "should calculate 75% for four values" do
      data = [
        %w[foo alpha],
        %w[foo bravo],
        %w[foo charlie],
        %w[foo delta]
      ]
      DecisionTree.gini_impurity(data).should == 0.75
    end

    it "should calculate the full data set correctly" do
      DecisionTree.gini_impurity(@data).should be_close(0.632, 0.005)
    end

    it "should calculate a divided set correctly" do
      s1, s2 = DecisionTree.divide(@data, 2, 'yes')
      DecisionTree.gini_impurity(s1).should be_close(0.531, 0.005)
    end
  end

  describe "entropy" do
    it "should calculate the full data set correctly" do
      DecisionTree.entropy(@data).should be_close(1.505, 0.005)
    end

    it "should calculate a divide set correctly" do
      s1, s2 = DecisionTree.divide(@data, 2, 'yes')
      DecisionTree.entropy(s1).should be_close(1.298, 0.005)
    end
  end

  describe "build_tree" do
    it "should build the correct tree for @data" do
      t = DecisionTree.build_tree(@data) do |x|
        DecisionTree.entropy(x)
      end
      t.value.should == 'google'
      t.column_index.should == 0
    end
  end
end
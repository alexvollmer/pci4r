require File.join(File.dirname(__FILE__), "/../lib/decision_tree")

class MatchNode
  def initialize(value, index)
    @value = value
    @index = index
  end

  def matches?(target)
    @target = target
    if target.results
      @target.results[@value].eql?(@index)
    else
      @target.value.eql?(@value) and @target.column_index.eql?(@index)
    end
  end

  def failure_message
    if @target.results
      "expected value: #{@value}, index: #{@index} to match (#{@target.results.inspect})"
    else
      "expected value: #{@value}, index: #{@index} to match (#{@target.value}:#{@target.column_index})"
    end
  end

  def negative_failure_message
    if @target.results
      "expected value: #{@value}, index: #{@index} to not (#{@target.results.inspect})"
    else
      "expected value: #{@value}, index: #{@index} to not (#{@target.value}:#{@target.column_index})"
    end
  end
end

def match_node(value, index)
  MatchNode.new(value, index)
end

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

  def build_tree
    DecisionTree.build_tree(@data) do |r|
      DecisionTree.entropy(r)
    end
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

    it "should divide correctly on a numeric value" do
      result = DecisionTree.divide(@data, 3, 21)
      result.size.should == 2
      matching = result.first.map { |m| m[3] }.sort
      matching.should == [21, 21, 21, 23, 23, 24, 24]

      not_matching = result.last.map { |m| m[3] }.sort
      not_matching.should == [12, 12, 18, 18, 18, 18, 19, 19, 19]
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
    ##
    # For reasons I can't yet figure out, the decision tree
    # node order gets flipped in Ruby. The end result is the
    # same, just nodes are negated so the assertions have to
    # switch from the 'true' node to the 'false' node.
    it "should build the correct tree for @data" do
      t = build_tree
      t.should match_node('google', 0)
      t.t_node.should match_node(21, 3)
      t.f_node.should match_node('slashdot', 0)
      t.t_node.t_node.should match_node('Premium', 3)
      t.t_node.f_node.should match_node('no', 2)
      t.t_node.f_node.t_node.should match_node('None', 1)
      t.t_node.f_node.f_node.should match_node('Basic', 1)

      t.f_node.t_node.should match_node('None', 3)
      t.f_node.f_node.should match_node('no', 2)
      t.f_node.f_node.t_node.should match_node(21, 3)
      t.f_node.f_node.f_node.should match_node('Basic', 4)
      t.f_node.f_node.t_node.t_node.should match_node('Basic', 1)
      t.f_node.f_node.t_node.f_node.should match_node('None', 3)
    end
  end

  describe "classify" do
    it "should classify correctly" do
      tree = build_tree
      tree.classify(['(direct)', 'USA', 'yes', 5]).should == {'Basic' => 4}
    end
  end

  describe "prune" do
    it "should prune correctly" do
      tree = build_tree

      tree.prune(0.1)
      tree.should match_node('google', 0)
      tree.t_node.should match_node(21, 3)
      tree.t_node.t_node.should match_node('Premium', 3)
      tree.t_node.f_node.should match_node('no', 2)
      tree.t_node.f_node.t_node.should match_node('None', 1)
      tree.t_node.f_node.f_node.should match_node('Basic', 1)

      tree.f_node.should match_node('slashdot', 0)
      tree.f_node.t_node.should match_node('None', 3)
      tree.f_node.f_node.should match_node('no', 2)
      tree.f_node.f_node.t_node.should match_node(21, 3)
      tree.f_node.f_node.t_node.t_node.should match_node('Basic', 1)
      tree.f_node.f_node.t_node.f_node.should match_node('None', 3)
      tree.f_node.f_node.f_node.should match_node('Basic', 4)

      tree.prune(1.0)
      tree.should match_node('google', 0)
      tree.t_node.should match_node(21, 3)
      tree.t_node.t_node.should match_node('Premium', 3)
      tree.t_node.f_node.should match_node('no', 2)
      tree.t_node.f_node.t_node.should match_node('None', 1)
      tree.t_node.f_node.f_node.should match_node('Basic', 1)
      tree.f_node.t_node.should be_nil
      tree.f_node.f_node.should be_nil
      tree.f_node.results.should == {'None' => 6, 'Basic' => 5}
    end
  end

  describe "classifying with missing data" do
    it "should classify correctly" do
      tree = build_tree
      x = tree.md_classify(["google", nil, "yes", nil], tree)
      # the book is incorrect here, this is the same answer the python code gives.
      x.should == { "Premium" => 2.25, "Basic" => 0.25 }

      x = tree.md_classify(["google", "France", nil, nil])
      x.should == { "None" => 0.125, "Premium" => 2.25, "Basic" => 0.125 }
    end
  end
end
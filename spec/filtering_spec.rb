#!/usr/bin/env ruby -wKU

require File.join(File.dirname(__FILE__), "..", "lib", "filtering")

describe "Filtering" do
  describe "get_words" do

    before(:each) do
      @words = Filtering.get_words(<<-DOC)
      Now is the time for all good men to come together.
      I want no antidisestablishmentantarianism at this time.
      DOC
    end

    it "should find thirteen words" do
      @words.size.should be(12)
    end
  
    it "should convert all words to lower case" do
      @words.each do |word|
        word.downcase.should == word
      end
    end

    it "should ignore words less than two characters" do
      @words.should_not be_member("I")
      @words.should_not be_member("is")
      @words.should_not be_member("at")
      @words.should_not be_member("to")
      @words.should_not be_member("no")            
    end

    it "should ignore words greater than twenty characters" do
      @words.should_not be_member("antidisestablishmentantarianism")
    end

    it "should contain only unique terms" do
      @words.should be_kind_of(Set)
    end
  end
  
  def sample_train(classifier)
    classifier.train("Nobody owns the water", :good)
    classifier.train("the quick rabbit jumps fences", :good)
    classifier.train("buy pharmaceuticals now", :bad)
    classifier.train("make quick money at the online casino", :bad)
    classifier.train("the quick brown fox jumps", :good)
  end

  describe "Classifier" do
    
    before(:each) do
      @classifier = Filtering::Classifier.new do |item|
        Filtering.get_words(item)
      end
    end
    
    it "should track feature counts correctly" do
      @classifier.train("the quick brown fox jumps over the lazy dog", :good)
      @classifier.train("make quick money in the online casino", :bad)
      @classifier.feature_count("quick", :good).should == 1.0
      @classifier.feature_count("quick", :bad).should == 1.0
      @classifier.feature_count("dog", :good).should == 1.0
      @classifier.feature_count("dog", :bad).should == 0.0
    end
    
    it "should calculate feature probability correctly Pr(quick | good) = 0.666" do
      sample_train(@classifier)
      @classifier.feature_probability("quick", :good).should be_close(0.666, 0.005)
    end
    
    it "should calculate weighted probability correctly" do
      fprob = lambda { |f,c| @classifier.feature_probability(f, c) }

      sample_train(@classifier)
      @classifier.weighted_probability("money", :good) do |f, c|
        @classifier.feature_probability(f, c)
      end.should == 0.25
      
      sample_train(@classifier)
      @classifier.weighted_probability("money", :good) do |f,c|
        @classifier.feature_probability(f, c)
      end.should be_close(0.166, 0.005)
    end
  end

  describe "NaiveBayes" do
    before(:each) do
      @classifier = Filtering::NaiveBayes.new do |item|
        Filtering.get_words(item)
      end
    end
    
    it "should calculate the correct document probability" do
      sample_train(@classifier)
      @classifier.prob("quick rabbit", :good).should be_close(0.156, 0.005)
      @classifier.prob("quick rabbit", :bad).should be_close(0.050, 0.005)
    end
    
    it "should calculate correctly with thresholds" do
      sample_train(@classifier)
      @classifier.classify("quick rabbit", :unknown).should == :good
      @classifier.classify("quick money", :unknown).should == :bad
      
      @classifier.thresholds[:bad] = 3.0
      @classifier.classify("quick money", :unknown).should == :unknown
      
      10.times { sample_train(@classifier) }
      @classifier.classify("quick money", :unknown).should == :bad
    end
  end
end
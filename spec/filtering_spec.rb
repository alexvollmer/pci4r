#!/usr/bin/env ruby -wKU

require File.join(File.dirname(__FILE__), "..", "lib", "filtering")
require "tempfile"

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
      @classifier = Filtering::Classifier.new
    end
    
    it "should track feature counts correctly (p 121)" do
      @classifier.train("the quick brown fox jumps over the lazy dog", :good)
      @classifier.train("make quick money in the online casino", :bad)
      @classifier.feature_count("quick", :good).should == 1.0
      @classifier.feature_count("quick", :bad).should == 1.0
      @classifier.feature_count("dog", :good).should == 1.0
      @classifier.feature_count("dog", :bad).should == 0.0
    end
    
    it "should calculate feature probability correctly (p 122)" do
      sample_train(@classifier)
      @classifier.feature_probability("quick", :good).should be_close(0.666, 0.005)
    end
    
    it "should calculate weighted probability correctly (p 123)" do
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

  describe "NaiveBayes classifier" do
    before(:each) do
      @classifier = Filtering::NaiveBayes.new
      sample_train(@classifier)
    end
    
    it "should calculate the correct document probability (p 125)" do
      @classifier.prob("quick rabbit", :good).should be_close(0.156, 0.005)
      @classifier.prob("quick rabbit", :bad).should be_close(0.050, 0.005)
    end
    
    it "should calculate correctly with thresholds (p 127)" do
      @classifier.classify("quick rabbit", :unknown).should == :good
      @classifier.classify("quick money", :unknown).should == :bad
      
      @classifier.thresholds[:bad] = 3.0
      @classifier.classify("quick money", :unknown).should == :unknown
      
      10.times { sample_train(@classifier) }
      @classifier.classify("quick money", :unknown).should == :bad
    end
  end
  
  describe "Fisher classifier" do
    before(:each) do
      @classifier = Filtering::Fisher.new
      sample_train(@classifier)
    end
    
    it "should calculcate basic probability correctly (p 129)" do
      @classifier.prob('quick', :good).should be_close(0.571, 0.005)
      @classifier.prob('money', :bad).should == 1.0
    end

    it "should calculcate Fisher probability correctly (p 130)" do
      @classifier.prob("quick", :good).should be_close(0.571, 0.005)
      @classifier.fisher_prob("quick rabbit", :good).should be_close(0.780, 0.005)
      @classifier.fisher_prob("quick rabbit", :bad).should be_close(0.356, 0.005)
    end

    it "should classify correctly using minimums (p 131)" do
      @classifier.classify("quick rabbit").should == :good
      @classifier.classify("quick money").should == :bad
      
      @classifier.minimums[:bad] = 0.8
      @classifier.classify("quick money").should == :good
    end
  end

  describe "ActiveRecord persistence" do

    ##
    # We need to have the 'sqlite3' gem installed to test the
    # ActiveRecord bits.
    require "rubygems"
    require "sqlite3"

    before(:each) do
      @tmpfile = Tempfile.new("pci4r")
      ar = Filtering::Persistence::ActiveRecordAdapter.new(
        :adapter => "sqlite3",
        :database => @tmpfile.path
      )
      @classifier = Filtering::Classifier.new(ar)
    end

    after(:each) do
      @tmpfile.unlink
    end

    it "should work the same with ActiveRecord persistence" do
      @classifier.train("the quick brown fox jumps over the lazy dog", :good)
      @classifier.train("make quick money in the online casino", :bad)
      @classifier.feature_count("quick", :good).should == 1.0
      @classifier.feature_count("quick", :bad).should == 1.0
      @classifier.feature_count("dog", :good).should == 1.0
      @classifier.feature_count("dog", :bad).should == 0.0
    end
  end
end
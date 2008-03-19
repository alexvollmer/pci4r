require "set"

##
# Chapter 6: Document Filtering.
# Toby called this file 'docclass.py' which struck me as 
# a little obscure.
module Filtering
  
  ##
  # Pull all of the words out of a given doc +String+
  # and normalize them
  def self.get_words(doc)
    words = Set.new
    doc.split(/\s+/).each do |word|       
      words << word.downcase if word.size > 2 && word.size < 20
    end
    words
  end

  class Classifier
    
    attr_reader :thresholds
    
    ##
    # Construct a new instance.
    # This requires a block that will accept a single item
    # and returns its features
    def initialize(filename=nil, &block)
      raise "You must provide a block" unless block_given?
      @feature_count = Hash.new do |h,k|
        h[k] = Hash.new { |h2,k2| h2[k2] = 0 }
      end
      @category_count = Hash.new { |h,k| h[k] = 0 }
      @get_features_func = block
      @thresholds = {}
      @thresholds.default = 0
    end

    ##
    # Invokes the block given in the +initialize+ method to
    # extract features for the given +item+
    def get_features(item)
      @get_features_func.call(item)
    end

    def increment_feature(feature, category)
      @feature_count[feature][category] += 1
    end
    
    def increment_category(category)
      @category_count[category] += 1
    end
    
    def feature_count(feature, category)
      if @feature_count.has_key?(feature) && @category_count.has_key?(category)
        @feature_count[feature][category].to_f
      else
        0.0
      end
    end
    
    ##
    # Returns the number of items in a given category
    def category_count(category)
      (@category_count[category] || 0).to_f
    end
    
    ##
    # Returns the total number of items
    def total_count
      total = 0
      @category_count.values.each do |v|
        total += v
      end
      total
    end
    
    ##
    # List all categories
    def categories
      @category_count.keys
    end
    
    def train(item, category)
      features = get_features(item)
      # increment the feature count
      features.each do |feature|
        increment_feature(feature, category)
      end
      # increment he category count
      increment_category(category)
    end
   
    ##
    # Returns the probably (between 0.0 and 1.0) of a feature
    # for a given category. Pr(feature | category)
    def feature_probability(feature, category)
      return 0 if category_count(category) == 0
      feature_count(feature, category) / category_count(category)
    end
    
    ##
    # Returns the weighted probability of a feature for a given category
    # using the +prf+ function to calculate with the given
    # +weight+ and +assumed_prob+ variables (both of which have defaults)
    #  - <tt>feature</tt>
    #  - <tt>category</tt>
    #  - <tt>prf</tt> - a probability function
    #  - <tt>weight</tt> - defaults to 1.0
    #  - <tt>assumed_prob</tt> - defaults to 0.5
    def weighted_probability(feature, category, weight=1.0, assumed_prob=0.5, &block)
      raise "You must provide a block" unless block_given?
      basic_probabilty = block.call(feature, category)
      
      totals = 0
      categories.each do |category|
        totals += feature_count(feature, category)
      end
      
      ((weight * assumed_prob) + (totals * basic_probabilty)) / (weight + totals)
    end
    
    def classify(item, default=nil)
      probs = {}
      probs.default = 0.0
      max = 0.0
      best = nil
      categories.each do |cat|
        probs[cat] = prob(item, cat)
        if probs[cat] > max
          max = probs[cat]
          best = cat
        end
      end
      
      probs.each do |cat, prob|
        next if cat == best
        if probs[cat] * thresholds[best] > probs[best]
          return default
        end
      end
      best
    end
  end
  
  class NaiveBayes < Classifier
    ##
    # Determines the probability that a given document is
    # within a given category.
    def document_probability(item, category)
      p = 1
      get_features(item).each do |f|
        p *= weighted_probability(f, category) do |f, c|
          self.feature_probability(f, c)
        end
      end
      p
    end
    
    ##
    # Returns the probability of the category, i.e.
    # Pr(Document|Category)
    def prob(item, category)
      cat_prob = category_count(category) / total_count
      doc_prob = document_probability(item, category)
      doc_prob * cat_prob
    end
  end
end
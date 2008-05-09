require "set"

module Math
  def self.logb(num, base)
    log(num) / log(base)
  end
end

class Array
  def sum
    inject(0) { |sum, v| sum + v }
  end
end

module DecisionTree
  
  ##
  # A node in a decision tree.
  class Node
    # The index of the criteria to be tested
    attr_reader :column_index
    # The value a column must match to be true
    attr_reader :value
    # The +Node+ for the "true" value
    attr_accessor :t_node
    # The +Node+ for the "false" value
    attr_accessor :f_node
    # A <tt>Hash</tt> of results for this branch
    attr_accessor :results

    VALID_KEYS = [ :index, :value, :true_node, :false_node, :results ]
    ##
    # Construct a new node instance with the following options (as symbols):
    #  * <tt>index</tt>
    #  * <tt>value</tt>
    #  * <tt>true_node</tt>
    #  * <tt>false_node</tt>
    #  * <tt>results</tt>
    def initialize(opts={})
      unknown = opts.keys - VALID_KEYS
      unless unknown.empty?
        raise "Invalid keys: #{unknown.inspect}"
      end

      @column_index = opts[:index]
      @value = opts[:value]
      @t_node = opts[:true_node]
      @f_node = opts[:false_node]
      @results = opts[:results]
    end

    def pretty_print(q)
      q.group(2, '#<node ', '>') do
        q.seplist([:value, :column_index, :results, :t_node, :f_node],
                  lambda { q.text ',' }) do |member|
          q.breakable
          q.text member.to_s
          q.text ' = '
          q.pp self.send(member)
        end
      end
    end

    def node_name
      if @results
        key = @results.keys.first
        "#{key}:#{@results[key]}"
      else
        "#{@column_index}:#{@value}"
      end
    end

    ##
    # Returns a <tt>String</tt> of graphviz "dot"-notation that
    # can be used to generate a directed graph visualization of
    # this tree instance.
    def to_dot(out=nil, parent_id=nil, generator=IdGenerator.new)
      top = out.nil?
      if top
        out = ""
        out << "digraph decision_tree {\n"
      end

      my_id = generator.next
      out << "  node[label=\"#{node_name}\"] #{my_id};\n"

      unless @results
        @t_node.to_dot(out, my_id, generator) if @t_node
        @f_node.to_dot(out, my_id, generator) if @f_node
      end

      if parent_id
        out << "  #{parent_id} -> #{my_id}\n"
      end

      if top
        out << "}"
      end
    end

    ##
    # Classifies a given +observation+ against the given +tree+.
    # Classification is essentially predicting the final outcome
    # using the given arguments.
    #
    # Given an observation array of data this method will return
    # a <tt>Hash</tt> of expected results.
    def classify(observation, tree=self)
      if tree.results
        tree.results
      else
        v = observation[tree.column_index]
        branch = case v.class
        when Numeric
          v >= tree.value ? tree.t_node : tree.f_node
        else
          v == tree.value ? tree.t_node : tree.f_node
        end
        classify(observation, branch)
      end
    end

    ##
    # A variation of the +classify+ method that attempts to deal
    # with missing data.
    def md_classify(observation, tree=self)
      if tree.results
        tree.results
      else
        v = observation[tree.column_index]
        if v.nil?
          tr = md_classify(observation, tree.t_node)
          fr = md_classify(observation, tree.f_node)
          tcount = tr.values.sum
          fcount = fr.values.sum
          tw = tcount.to_f / (tcount + fcount)
          fw = fcount.to_f / (tcount + fcount)
          result = {}
          tr.each { |k,v| result[k] = v * tw }
          fr.each { |k,v| result[k] = v * fw }
          result
        else
          branch = case v.class
          when Numeric
            v >= tree.value ? tree.t_node : tree.f_node
          else
            v == tree.value ? tree.t_node : tree.f_node
          end
          md_classify(observation, branch)
        end
      end
    end

    ##
    # Attempt to avoid 'overfitted' trees giving overly-definitive
    # answers when they may not, in fact, be correct. Pruning is
    # done by checking node-pairs to see if they can be merged
    # with the parent node. This can be done if the increase in
    # entropy for the parent node is no more than the threshold
    # specified by the +min_gain+ parameter.
    def prune(min_gain, tree=self)
      if tree.t_node.results.nil?
        prune(min_gain, tree.t_node)
      end

      if tree.f_node.results.nil?
        prune(min_gain, tree.f_node)
      end

      if tree.t_node.results and tree.f_node.results
        tb, fb = [], []
        tree.t_node.results.each { |v,c| tb.concat [[v]] * c }
        tree.f_node.results.each { |v,c| fb.concat [[v]] * c }
        delta = DecisionTree.entropy(tb + fb) - (DecisionTree.entropy(tb) + DecisionTree.entropy(fb) / 2.to_f)
        if delta < min_gain
          tree.t_node, tree.f_node = nil, nil
          tree.results = DecisionTree.unique_counts(tb + fb)
        end
      end
    end
  end

  class IdGenerator # :nodoc:
    def next
      unless @value
        @value = 'A'
      else
        @value = @value.next
      end
    end
  end

  ##
  # Divides a the given set (+rows+) based on the given +column+ index
  # using the given +value+ as a pivot value. Splitting on numeric values
  # is done based on whether or not a value is greater than or equal to
  # the given value.  Otherwise, splitting is done on whether or not the
  # set value is equal to the splitting value.
  def self.divide(rows, column, value)
    set1, set2 = rows.partition do |x|
      if value.kind_of?(Numeric)
        x[column] >= value
      else
        x[column] == value
      end
    end
  end

  ##
  # Calculates the expected error rate if one of the results is randomly
  # applied to one of the items in the set.
  def self.gini_impurity(rows)
    total = rows.size
    counts = unique_counts(rows)
    impurity = 0
    counts.each do |value, count|
      p1 = count.to_f / total.to_f
      counts.each do |value2, count2|
        unless value2 == value
          p2 = count2.to_f / total.to_f
          impurity += p1 * p2
        end
      end
    end
    impurity
  end

  ##
  # A scoring function that can be used instead of +entropy+ or 
  # +gini_impurity+ when you have numeric outcomes. This method
  # considers distance when scoring numerically so that values
  # further apart return higher numbers
  #
  # A low variance means the values are close together, a high
  # value indicates that they are further apart.
  def self.variance(rows)
    return 0 if rows.empty?
    data = rows.map { |r| r.last.to_f }
    mean = rows.sum / rows.size
    data.map { |d| (d - mean) ** 2 }.sum / data.size
  end

  ##
  # Measures the amount of disorder in the given set.
  def self.entropy(rows)
    results = unique_counts(rows)
    entropy = 0.0
    results.values.each do |v|
      p = v.to_f / rows.size.to_f
      entropy = entropy - p * Math.logb(p, 2).to_f
    end
    entropy
  end

  ##
  # Builds a decision tree using the score returned by the given
  # block. The block receives the entire data set given in the
  # +rows+ attribute and scores it accordingly for information
  # gain. The highest score returned for each data set is used
  # to further sub-divide the data set into tree nodes.
  #
  # This method continues to recursively sub-divide the dataset
  # until no further information gain is possible (also occurs
  # when the data set is no longer divisible.)
  def self.build_tree(rows, &block)
    block = lambda { |x| entropy(x) } unless block
    return Node.new if rows.empty?

    current_score = block.call(rows)
    best_gain = 0.0
    best_criteria = nil
    best_sets = nil

    column_count = rows[0].size - 1
    # Iterate through each column to find the best split
    # based on information gain
    (0...column_count).each do |col|
      # the set of unique values for a particular column
      column_values = Set.new(rows.map { |row| row[col] })

      # for each column value, divide the set based on the
      # value, updating best_gain, best_sets and best_criteria
      # along the way
      column_values.each do |value|
        set1, set2 = divide(rows, col, value)
        p = set1.size.to_f / rows.size.to_f
        p1 = p * block.call(set1)
        p2 = block.call(set2)
        gain = current_score - p1 - (1 - p) * p2  # information gain
        if gain > best_gain and set1.size > 0 and set2.size > 0
          best_gain = gain
          best_criteria = [col, value]
          best_sets = [set1, set2]
        end
      end
    end

    if best_gain > 0
      true_branch = build_tree(best_sets[0], &block)
      false_branch = build_tree(best_sets[1], &block)
      Node.new(:index => best_criteria[0],
               :value => best_criteria[1],
               :true_node => true_branch,
               :false_node => false_branch)
    else
      Node.new(:results => unique_counts(rows))
    end
  end

  private

  # :nodoc:
  def self.unique_counts(rows)
    results = Hash.new { |h,k| h[k] = 0 }
    rows.each do |row|
      results[row.last] += 1
    end
    results
  end
end
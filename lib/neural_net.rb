#!/usr/bin/env ruby

require "rubygems"
require "sqlite3"

# TODO: document
# TODO: replace sqlite3 with ActiveRecord
# TODO: remove silly chapter/section headings in comments
module Searching

  ##
  # 4.7
  # A neural-net class with two layers. These are stored internally
  # within database tables (in sqlite3). The the 'hidden_node' table
  # serves as the "hidden" layer between the 'word_hidden' and
  # 'hidden_url' tables.
  class SearchNet
  
    attr_reader :word_ids, :hidden_ids, :url_ids
    attr_reader :all_in, :all_hidden, :all_out
    attr_reader :weights_in, :weights_out

    def initialize(db_name)
      @db = SQLite3::Database.new(db_name)
      if @db.table_info('hidden_node').empty?
        make_tables
      end
    end
    
    def close
      @db.close
    end
    
    def commit
      # commit with SQLite3 seems quite broken
      # @db.commit
    end

    ##
    # delegate +execute+ calls to SQLite3 connection
    def execute(*args)
      @db.execute(*args)
    end

    ##
    # delegate +get_first_row+ calls to SQLite3 connection
    def get_first_row(*args)
      @db.get_first_row(*args)
    end

    def make_tables
      @db.execute("create table hidden_node(create_key)")
      @db.execute("create table word_hidden(from_id, to_id, strength)")
      @db.execute("create table hidden_url(from_id, to_id, strength)")
    end
    
    ##
    # 4.7.2
    # Get the stength for the given connection ids (from_id, to_id)
    # and the given layer, which must be a 0 or 1
    def get_strength(from_id, to_id, layer)
      raise ArgumentError.new("layer must be 0 or 1") unless [0,1].member?(layer)
      table = (layer == 0 ? 'word_hidden' : 'hidden_url')
      res = @db.get_first_row("select strength from #{table} where from_id = ? and to_id = ?", from_id, to_id)
      if res
        return res[0].to_f
      else
        return -0.2 if layer == 0
        return 0 if layer == 1
      end
    end
    
    ##
    # 4.7.2
    # Set the strength for the given connection (from_id and to_id)
    # at the given layer (which must be a 1 or 0). If the connection
    # already exists, it updates the strength of the connection.
    def set_strength(from_id, to_id, layer, strength)
      raise ArgumentError.new("layer must be 0 or 1") unless [0,1].member?(layer)
      table = (layer == 0 ? 'word_hidden' : 'hidden_url')
      res = @db.get_first_row("select rowid from #{table} where from_id = ? and to_id = ?", from_id, to_id)
      if res
        rowid = res[0].to_i
        @db.execute("update #{table} set strength = ? where rowid = ?", strength, rowid)
      else
        @db.execute("insert into #{table} (from_id, to_id, strength) values (?, ?, ?)", from_id, to_id, strength)
      end
    end
    
    ##
    # 4.7.2
    # Create new connections for linked words that the net doesn't
    # yet know about. It creates default-weighted links between the
    # words and the hidden node, and between the query node and
    # the URL results
    def generate_hidden_node(word_ids, url_ids)
      return if word_ids.size > 3
      key = word_ids.sort_by { |w| w.to_s }.join('_')
      res = @db.get_first_row("select rowid from hidden_node where create_key = ?", key)
      
      # If we don't have a record for that key, create it
      if res.nil?
        @db.execute("insert into hidden_node (create_key) values (?)", key)
        hidden_id = @db.last_insert_row_id
        # put in our default weights
        word_ids.each do |word_id|
          set_strength(word_id.to_i, hidden_id, 0, 1.0 / word_ids.size)
        end
        
        url_ids.each do |url_id|
          set_strength(hidden_id, url_id.to_i, 1, 0.1)
        end
        commit
      end
    end
    
    ##
    # 4.7.3
    # Finds all the relevant node IDs in the hidden layer that are
    # connected either to one of the given +word_ids+ or one of
    # the given +url_ids+
    def get_all_hidden_ids(word_ids, url_ids)
      results = []
      word_ids.each do |word_id|
        @db.execute("select to_id from word_hidden where from_id = ?", word_id.to_i).each do |row|
          results << row[0].to_i
        end
      end
      
      url_ids.each do |url_id|
        @db.execute("select from_id from hidden_url where to_id = ?", url_id.to_i).each do |row|
          results << row[0].to_i
        end
      end
      
      results.uniq
    end

    ##
    # 4.7.3
    # Constructs the relevant network in memory with the current
    # weights from the database
    def setup_network(word_ids, url_ids)
      # value lists
      @word_ids = word_ids
      @hidden_ids = get_all_hidden_ids(word_ids, url_ids)
      @url_ids = url_ids

      # node outputs
      @all_in = @word_ids.map { |w| 1.0 }
      @all_hidden = @hidden_ids.map { |h| 1.0 }
      @all_out = @url_ids.map { |u| 1.0 }

      # create weights matrices
      @weights_in = word_ids.map do |word_id|
        hidden_ids.map do |hidden_id|
          get_strength(word_id, hidden_id, 0)
        end
      end

      @weights_out = hidden_ids.map do |hidden_id|
        url_ids.map do |url_id|
          get_strength(hidden_id, url_id, 1)
        end
      end
    end

    ##
    # 4.7.3
    # Pushes the given list of inputs through the network,
    # returning the output of the nodes of the output layer.
    def feed_forward
      # light up the input nodes corresponding to the
      # words in our query
      word_ids.size.times do |i|
        all_in[i] = 1.0
      end
      
      # hidden activations
      hidden_ids.size.times do |j|
        sum = 0.0
        word_ids.size.times do |i|
          sum += all_in[i] * weights_in[i][j]
        end
        all_hidden[j] = Math.tanh(sum)
      end

      #output activations
      url_ids.size.times do |k|
        sum = 0.0
        hidden_ids.size.times do |j|
          sum += all_hidden[j] * weights_out[j][k]
        end
        all_out[k] = Math.tanh(sum)
      end

      all_out
    end
    
    ##
    # 4.7.3
    # A single method to get it all done
    def get_result(word_ids, url_ids)
      setup_network(word_ids, url_ids)
      feed_forward
    end

    ##
    # 4.7.4
    # Get the slope of the current value
    def dtanh(y)
      1.0 - y * y
    end

    ##
    # 4.7.4
    # back propogation to train the network
    def back_propogate(targets, n = 0.5)
      # calculate errors for output
      output_deltas = url_ids.map { |e| 0.0 }
      url_ids.size.times do |k|
        error = targets[k] - all_out[k]
        output_deltas[k] = dtanh(all_out[k]) * error
      end

      # calculate errors for hidden layer
      hidden_deltas = hidden_ids.map { |e| 0.0 }
      hidden_ids.size.times do |j|
        error = 0.0
        url_ids.size.times do |k|
          error += output_deltas[k] * weights_out[j][k]
        end
        hidden_deltas[j] = dtanh(all_hidden[j]) * error
      end

      # update output weights
      hidden_ids.size.times do |j|
        url_ids.size.times do |k|
          change = output_deltas[k] * all_hidden[j]
          weights_out[j][k] += n * change
        end
      end

      # update input weights
      word_ids.size.times do |i|
        hidden_ids.size.times do |j|
          change = hidden_deltas[j] * all_in[i]
          weights_in[i][j] += n * change
        end
      end
    end

    ##
    # 4.7.4
    # Persist our final results back to the database
    def update_database
      word_ids.size.times do |i|
        hidden_ids.size.times do |j|
          set_strength(word_ids[i], hidden_ids[j], 0, weights_in[i][j])
        end
      end

      hidden_ids.size.times do |j|
        url_ids.size.times do |k|
          set_strength(hidden_ids[j], url_ids[k], 1, weights_out[j][k])
        end
      end

      commit
    end

    ##
    # 4.7.4
    # The whole shebang:
    #  - run +setup_network+
    #  - run +feed_forward+
    #  - run +back_propogate+
    def train_query(word_ids, url_ids, selected_url)
      # generate a hidden node if necessary
      generate_hidden_node(word_ids, url_ids)
      
      setup_network(word_ids, url_ids)
      feed_forward
      targets = url_ids.map { |e| 0.0 }
      targets[url_ids.index(selected_url)] = 1.0
      error = back_propogate(targets)
      update_database
    end
  end
end

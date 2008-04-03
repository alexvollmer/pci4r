#!/usr/bin/env ruby

require "rubygems"
require "hpricot"
require "open-uri"
require "set"
require "activerecord"
require "uri"

# re-open Array to provide a simple way to map each
# item to a key-value pair with the given block
class Array
  def to_hash(&block)
    Hash[*self.map(&block).flatten]
  end
end

##
# This module contains two main classes to support searching, the
# +Crawler+ and the +Searcher+. Both rely on an underlying RDBMS
# system for storage. RDBMS access is handled by <tt>ActiveRecord</tt>
# or Ruby on Rails fame.
# === Crawling
# Crawling involves creating an instance of the +Crawler+, and having
# it crawl a given set of URLs:
#   crawler = Searching::Crawler(:adapter => "sqlite3", :name => "search.sqlite3")
#   crawler.crawl([
#     http://www.slashdot.org,
#     http://www.baseballprospectus.com,
#     http://blog.livollmers.net
#   ])
# After crawling, pages can be ranked internally according to a
# page-ranking algorithm. Page ranking can be performed by:
#   crawler.calculate_page_rank
# === Searching
# Searching is accomplished with an instance of the +Searcher+ class.
module Searching
  
  module Persistence
    def self.if_missing(name, tables)
      raise "No block given" unless block_given?
      unless tables.member?(name)
        yield
      end
    end

    def self.setup_database(conn)
      tables = conn.tables
      if_missing("urls", tables)
        conn.create_table(:urls) do |t|
          t.string :url
          t.decimal :page_rank
        end
        conn.add_index(:urls, :url, :unique => true)        
      end

      if_missing("words", tables)
        conn.create_table(:words) do |t|
          t.string :word
        end
        conn.add_index(:words, :word, :unique => true)
      end

      if_missing("word_locations", tables)
        conn.create_table(:word_locations) do |t|
          t.integer :word_id, :url_id, :location
        end
        conn.add_index(:word_locations, :word_id)
        conn.add_index(:word_locations, :url_id)
      end

      if_missing("links", tables)
        conn.create_table(:links) do |t|
          t.integer :from_id, :to_id
        end
        # FIXME: are these indexes correct?
        conn.add_index(:links, [:from_id, :to_id], :unique => true)
      end

      if_missing("link_words", tables)
        conn.create_table(:link_words) do |t|
          t.integer :word_id, :link_id
        end
        # FIXME: are these indexes correct?
        conn.add_index(:link_words, [:word_id, :link_id], :unless => true)
      end
    end
  end

  class WordLocation < ActiveRecord::Base
    belongs_to :word
    belongs_to :url
  end

  class LinkWord < ActiveRecord::Base
    belongs_to :word
    belongs_to :link
  end

  class Url < ActiveRecord::Base
    has_many :word_locations
    has_many :words, :through => :word_locations
  end

  class Word < ActiveRecord::Base
    has_many :word_locations
    has_many :urls, :through => :word_locations
    has_many :link_words
    has_many :links, :through => :link_words
  end

  class Link < ActiveRecord::Base
    has_many :words, :through => :link_words
  end
  
  IGNORE_WORDS = %w(the of to and a in is it)
  
  ##
  # The +Crawler+ handles the web-crawling of specific URLs and the
  # storage of how pages are linked to one another. Based on this,
  # The +Crawler+ can also perform a form of page-ranking.
  class Crawler
    
    ##
    # Creates a new instance based on the config hash given. This
    # is used to bootstrap an <tt>ActiveRecord</tt> connection so
    # the hash must meet the conditions of the 
    # <tt>ActiveRecord::Base.establish_connection</tt> method.
    def initialize(config)
      ActiveRecord::Base.establish_connection(config)
      Persistence.setup_database(ActiveRecord::Base.connection)
    end

    ##
    # Crawl a given set of URLs up to a maximum depth (default 2)
    def crawl(pages, depth=2)
      depth.times do
        new_pages = Set.new
        pages.each do |page|
          begin
            doc = Hpricot(open(page))
          rescue
            printf "Could not open %s\n", page
            next
          end
        
          add_to_index(page, doc)
        
          (doc/'a').each do |link|
            if link['href']
              url = URI.join(page, link['href']).to_s
              next if url =~ /'/
              url = url.split('#').first # drop the fragment
              if url[0,4] == 'http' and not is_indexed(url)
                new_pages << url
              end
              link_text = get_text_only(link)
              add_link_ref(page, url, link_text)
            end
          end
        end
      
        pages = new_pages
      end
    end

    ##
    # Resets the stored page rank and re-calculates the rank for
    # all pages in the database. After calling this method pages
    # can be queried for to get their new rank.
    def calculate_page_rank(iterations=20)
      # zero everyone's page rank out
      Url.update_all("page_rank = 1.0")

      iterations.times do |i|
        puts "Iteration #{i}"
        Url.find(:all).each do |url|
          pr = 0.15
          
          # loop through all the pages that link to this one
          Link.find(:all,
                    :select => "DISTINCT from_id",
                    :conditions => { :to_id => url.id }) do |link|
            from_id = link.from_id
            # get the page rank of the linker
            linking_pr = Url.find_by_id(from_id).page_rank
            
            # get the total number of links from the linker
            linking_count = Link.count(:conditions => { :from_id => from_id })

            pr += 0.85 * (linking_pr / linking_count)
          end

          Url.update_all(["page_rank = ?", pr], ["id = ?", url.id])
        end
      end
    end

    private
    ##
    # Get all of the text out of the given +doc+, shedding the
    # markup tags along the way
    def get_text_only(doc)
      text = StringIO.new
      if doc.kind_of?(Hpricot::Text)
        text.printf("%s\n", doc.to_s.strip) unless doc.to_s.strip.empty?
      else
        if doc.respond_to?(:children)
          doc.children.each do |child|
            text.printf(" %s", get_text_only(child))
          end
        end
      end
      text.string.strip
    end
  
    def separate_words(text)
      text.downcase.split(/\W+/).reject { |x| x.empty? }
    end

    ##
    # Is this URL already in the index?
    def is_indexed(url)
      u = Url.find_by_url(url)
      u and not u.words.empty?
    end

    ##
    # Add the given +doc+ to the index and link it to the given +url+
    def add_to_index(url, doc)
      unless is_indexed(url)
        # FIXME: replace with logging
        puts "Indexing #{url}..."
        
        # Get the individual words
        text = get_text_only(doc)
        words = separate_words(text)
        
        u = Url.find_by_url(url)
        if u.nil?
          u = Url.create!(:url => url)
        end
        
        # Link each word to this url
        words.each_with_index do |word, i|
          unless IGNORE_WORDS.member?(word)
            w = Word.find_by_word(word)
            if w.nil?
              w = Word.create!(:word => word)
            end
            w.word_locations.create!(:url_id => u.id, :location => i)
          end
        end
      end
    end
    
    def add_link_ref(url_from, url_to, link_text)
      # from_id = get_entry_id("url_list", "url", url_from)
      # to_id = get_entry_id("url_list", "url", url_to)
      # word_id = get_entry_id("word_list", "word", link_text)
      # unless @db.get_first_row("select * from link where from_id = ? and to_id = ?", from_id, to_id)
      #   
      # end
    end

    def connection
      ActiveRecord::Base.connection
    end

  end

  class Searcher

    attr_accessor :weights

    ##
    # Create a new +Searcher+ instance with a +Hash+ of parameters
    # to configure <tt>ActiveRecord</tt>.
    def initialize(config)
      require File.join(File.dirname(__FILE__), "neural_net")
      ActiveRecord::Base.establish_connection(config)
      Persistence.setup_database(ActiveRecord::Base.connection)
      @nn = Searching::SearchNet.new(config)
      @weights = [
        [1.0, :location_score ],
        [1.0, :frequency_score],
        [1.0, :page_rank_score],
        [1.0, :link_text_score]
      ]
    end

    def connection
      ActiveRecord::Base.connection
    end

    ##
    # Returns two elements for the given query. The first element
    # is an array of rows, each containing the rowid of the matching
    # url and the remaining values indicating the location of each
    # word in the query in that url.
    #
    # The second element is an array of rowids matching each word
    # given in the original +query+
    def get_match_rows(query)
      fields = 'w0.url_id'
      tables = ''
      clauses = ''
      word_ids = []
    
      words = query.split(' ')
      table_number = 0
    
      words.each do |word|
        word_row = 
          connection.execute("select rowid from word_list where word = '#{word}'").first
      
        if word_row
          word_id = word_row[0]
          word_ids << word_id
          if table_number > 0
            tables << ','
            clauses << " and w#{table_number - 1}.url_id = w#{table_number}.url_id and "
          end
          fields << ", w#{table_number}.location"
          tables << "word_location w#{table_number}"
          clauses << "w#{table_number}.word_id = #{word_id}"
          table_number += 1
        end
      end
    
      full_query = "select #{fields} from #{tables} where #{clauses}"
      rows = connection.execute(full_query)
      [rows, word_ids]
    end

    ##
    # returns a +Hash+ of url rowid to score. Scoring is based
    # on the +weights+ attribute, which has a default value declared
    # in the +initialize+ method.
    def get_scored_list(rows, word_ids)
      total_scores = rows.to_hash { |row| [row[0], 0] }

      weights.each do |weight, func|
        scores = self.send(func, rows, word_ids)
        total_scores.keys.each do |url|
          total_scores[url] += weight * scores[url]
        end
      end
      
      return total_scores
    end

    ##
    # Get the URL for the given +id+
    def get_url_name(id)
      Url.find(id).url
    end

    ##
    # Take the given query and return the top 10 results.
    def query(query, print=false)
      rows, word_ids = get_match_rows(query)
      scores = get_scored_list(rows, word_ids)
      scores.to_a.sort_by { |score| score[1] }.reverse
    end
    
    ##
    # Normalize the given +scores+ between 0.0 and 1.0. The
    # +small_is_better+ flag indicates which direction to weight
    # the given scores.
    def normalize_scores(scores, small_is_better=false)
      vsmall = 0.00001
      if small_is_better
        min_score = scores.values.min
        return scores.to_a.to_hash { |u,l| [u, min_score.to_f / [vsmall, l].max] }
      else
        max_score = scores.values.max
        max_score = vsmall if max_score == 0
        return scores.to_a.to_hash { |u,c| [u, c.to_f / max_score] }
      end
    end

    ##
    # score by word frequency (normalized)
    #---
    # TODO: change this to take two args, with the second defaulted
    def frequency_score(*args)
      rows = args.first
      counts = rows.to_hash { |row| [row[0], 0] }
      rows.each { |row| counts[row[0]] += 1 }
      normalize_scores(counts)
    end

    ##
    # score by document location (normalized)
    #---
    # TODO: change this to take two args, with the second defaulted
    def location_score(*args)
      rows = args.first
      locations = rows.to_hash { |row| [row[0], 1000000] }
      rows.each do |row|
        loc = row[1..row.size].inject(0) { |memo, value| memo += value.to_i; memo }
        if loc < locations[row[0]]
          locations[row[0]] = loc
        end
      end
      
      normalize_scores(locations, true)
    end
    
    ##
    # score by word distance
    #---
    # TODO: change this to take two args, with the second defaulted
    def distance_score(*args)
      rows = args.first
      # if there's only one word, everyone wins!
      if rows[0].size <= 2
        rows.to_hash { |row| [row[0], 1,0] }
      else
        min_dist = rows.to_hash { |row| [row[0], 1000000] }

        rows.each do |row|
          dist = 0
          (2..row.size).each do |i|
            dist += (row[i].to_i - row[i - 1].to_i).abs
          end

          if dist < min_dist[row[0]]
            min_dist[row[0]] = dist
          end
        end
        normalize_scores(min_dist, true)
      end
    end
  
    ##
    # score by inbound link count
    #---
    # TODO: change this to take two args, with the second defaulted
    def inbound_link_score(*args)
      rows = args.first
      unique_urls = Set.new(rows.map { |row| row[0] })
      inbound_count = unique_urls.to_hash do |url|
        [
          url, 
          Link.count(:conditions => ["to_id = ?", url])
        ]
      end
      
      normalize_scores(inbound_count)
    end
    
    ##
    # score by page_rank table
    #---
    # TODO: change this to take two args, with the second defaulted
    def page_rank_score(*args)
      rows = args.first
      page_ranks = rows.map do |row|
        [
          row[0],
          PageRank.find_by_url_id(row[0]).page_rank.to_f
          # @db.get_first_row("select score from page_rank where url_id = ?", row[0].to_i)[0].to_f
        ]
      end

      max_rank = page_ranks.map { |r| r[1].to_f }.max
      page_ranks.to_hash do |url, score|
        [url, score.to_f / max_rank]
      end
    end
    
    ##
    # Score by the page rank of text from inbound links
    #---
    # TODO: change this to take two args
    def link_text_score(*args)
      rows, word_ids = args
      link_scores = rows.to_hash { |row| [ row[0], 0 ] }
      word_ids.each do |word_id|
        # TODO: replace with ActiveRecord
        @db.execute("select l.from_id, l.to_id from link_words w, link l where w.word_id = ? and w.link_id = l.rowid", word_id.to_i).each do |from, to|
          if link_scores.has_key? to
            pr = @db.get_first_row("select score from page_rank where url_id = ?", from.to_i)[0].to_f
            link_scores[to] += pr
          end
        end
      end
      
      max_score = link_scores.values.max
      link_scores.to_a.to_hash do |url, score|
        [ url, score / max_score ]
      end
    end

    ##
    # Use the neural-net to score results
    def nn_score(rows, word_ids)
      url_ids = rows.map { |row| row[0] }.uniq
      nn_res = @net.get_result(word_ids, url_ids)
      scores = {}
      url_ids.size.times do |i|
        scores[url_ids[i]] = nn_res[i]
      end
      
      normalize_scores(scores)
    end
  end
end

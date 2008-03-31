#!/usr/bin/env ruby

require "rubygems"
require "hpricot"
require "open-uri"
require "set"
require "activerecord"
require "uri"

# re-open Array to provide a simple way to map each
# item to a key-value pair
class Array
  def to_hash(&block)
    Hash[*self.map(&block).flatten]
  end
end

module Searching
  
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
  
  class Crawler
    def initialize(config)
      ActiveRecord::Base.establish_connection(config)
      c = ActiveRecord::Base.connection
      tables = c.tables
      unless tables.member?("urls")
        c.create_table(:urls) do |t|
          t.string :url
          t.decimal :page_rank
        end
        c.add_index(:urls, :url, :unique => true)
      end

      unless tables.member?("words")
        c.create_table(:words) do |t|
          t.string :word
        end
        c.add_index(:words, :word, :unique => true)
      end

      unless tables.member?("word_locations")
        c.create_table(:word_locations) do |t|
          t.integer :word_id, :url_id, :location
        end
        c.add_index(:word_locations, :word_id)
        c.add_index(:word_locations, :url_id)
      end

      unless tables.member?("links")
        c.create_table(:links) do |t|
          t.integer :from_id, :to_id
        end
        # FIXME: are these indexes correct?
        c.add_index(:links, [:from_id, :to_id], :unique => true)
      end

      unless tables.member?("link_words")
        c.create_table(:link_words) do |t|
          t.integer :word_id, :link_id
        end
        # FIXME: are these indexes correct?
        c.add_index(:link_words, [:word_id, :link_id], :unless => true)
      end
    end
  
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

    ##
    # Since we're in Ruby, we use Hpricot instead of Beautiful Soup.
    # Crawl each page in <tt>pages</tt> trolling each for hyperlinks. Repeat
    # the process to the given maximum <tt>depth</tt>
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

    def connection
      ActiveRecord::Base.connection
    end

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
  end

  class Searcher

    attr_accessor :weights
  
    def initialize(dbname, nndb='db/nn.db')
      @db = SQLite3::Database.new(dbname)
      @nn = Searching::SearchNet.new(nndb)
      @weights = [
        [1.0, :location_score ],
        [1.0, :frequency_score],
        [1.0, :page_rank_score],
        [1.0, :link_text_score]
      ]
    end
  
    def close
      @db.close
    end

    ##
    # 4.4
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
          @db.get_first_row("select rowid from word_list where word = '#{word}'")
      
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
      rows = @db.execute(full_query)
      [rows, word_ids]
    end

    ##
    # 4.5
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
    # 4.5
    # Get the URL for the given +id+
    def get_url_name(id)
      return @db.get_first_row("select url from url_list where rowid = ?", id)
    end

    ##
    # 4.5
    # Take the given query and return the top 10 results.
    def query(query, print=false)
      rows, word_ids = get_match_rows(query)
      scores = get_scored_list(rows, word_ids)
      scores.to_a.sort_by { |score| score[1] }.reverse
    end
    
    ##
    # 4.5.1
    # Normalize the given +scores+ between 0.0 and 1.0. The
    # +small_is_better+ flag indicates which direction to weight
    # the given scores.
    def normalize_scores(scores, small_is_better=false)
      vsmall = 0.00001
      if small_is_better
        min_score = scores.values.min
        # return Hash[*scores.to_a.map { |u,l| [u, min_score.to_f / [vsmall, l].max] }.flatten]
        return scores.to_a.to_hash { |u,l| [u, min_score.to_f / [vsmall, l].max] }
      else
        max_score = scores.values.max
        max_score = vsmall if max_score == 0
        # return Hash[*scores.to_a.map { |u,c| [u, c.to_f / max_score] }.flatten]
        return scores.to_a.to_hash { |u,c| [u, c.to_f / max_score] }
      end
    end

    ##
    # 4.5.2
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
    # 4.5.3
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
    # 4.5.4
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
    # 4.6.1
    # score by inbound link count
    #---
    # TODO: change this to take two args, with the second defaulted
    def inbound_link_score(*args)
      rows = args.first
      unique_urls = Set.new(rows.map { |row| row[0] })
      inbound_count = unique_urls.to_hash do |url|
        [
          url, 
          @db.execute("select count(*) from link where to_id = #{url}").first
        ]
      end
      
      normalize_scores(inbound_count)
    end
    
    ##
    # 4.6.2
    # score by page_rank table
    #---
    # TODO: change this to take two args, with the second defaulted
    def page_rank_score(*args)
      rows = args.first
      page_ranks = rows.map do |row|
        [
          row[0],
          @db.get_first_row("select score from page_rank where url_id = ?", row[0].to_i)[0].to_f
        ]
      end

      max_rank = page_ranks.map { |r| r[1].to_f }.max
      page_ranks.to_hash do |url, score|
        [url, score.to_f / max_rank]
      end
    end
    
    ##
    # 4.6.3
    # Score by the page rank of text from inbound links
    #---
    # TODO: change this to take two args
    def link_text_score(*args)
      rows, word_ids = args
      link_scores = rows.to_hash { |row| [ row[0], 0 ] }
      word_ids.each do |word_id|
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
    # 4.7.6
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

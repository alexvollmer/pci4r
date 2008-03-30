#!/usr/bin/env ruby

module Clusters
  
  ##
  # Returns a triple of data:
  #  row_names: an array of blogs
  #  col_names: an array of words
  #  data: a two-dimensional array of the cell data
  def self.readfile(filename)
    lines = File.open(filename).readlines
    col_names = lines.first.strip().split("\t")[1..-1]
    row_names = []
    data = []
    lines[1..-1].each do |line|
      p = line.strip.split("\t")
      row_names << p.first
      data << p[1..-1].map { |x| x.to_f }
    end
    
    return row_names, col_names, data
  end
  
  ##
  # Another Pearson function. This is used in place of Euclidean
  # distance since Pearson better accounts for blogs that have
  # many more words than others
  def self.pearson(v1, v2)
    sum1 = v1.inject(0) { |sum, value| sum + value }
    sum2 = v2.inject(0) { |sum, value| sum + value }
    
    sum1_sq = v1.inject(0) { |sum, value| sum + (value ** 2) }
    sum2_sq = v2.inject(0) { |sum, value| sum + (value ** 2) }
    
    product_sum = 0
    v1.each_with_index do |obj, i|
      product_sum += (obj * v2[i])
    end
    
    num = product_sum - (sum1 * sum2 / v1.size)
    den = Math.sqrt((sum1_sq - (sum1**2) / v1.size) * (sum2_sq - (sum2**2) / v2.size))
    return 0 if den == 0
    
    return 1.0 - num / den
  end

  class BiCluster
    
    attr_accessor :vec, :left, :right, :distance, :id_num
    
    def initialize(vec, id_num=nil, left=nil, right=nil, distance=0.0)
      @vec = vec
      @left = left
      @right = right
      @distance = distance
      @id_num = id_num
    end
    
    def to_s
      "BiCluster: <#{@id_num}> vector: #{@vec.inspect} left: #{@left ? @left.id_num : 'nil'} right: #{@right ? @right.id_num : 'nil'}"
    end
    
    alias :inspect :to_s
  end
  
  ##
  # Computes the highest-level (hierarchical) cluster from the given <tt>rows</tt> data.
  # <tt>rows</tt>: A two-dimensional array of vector data
  # <tt>distance</tt>: A function reference/block to calculate distance (def. +Clusters.pearson+)
  def self.h_cluster(rows, &distance)
    distance = lambda { |v1, v2| Clusters.pearson(v1, v2) } unless distance
    distances = Hash.new
    current_cluster_id = -1
    
    clust = []
    rows.each_with_index do |row, i|
      clust << BiCluster.new(row, i)
    end

    while clust.size > 1
      lowest_pair = [0, 1]
      closest = distance.call(clust[0].vec, clust[1].vec)
      
      # compare each BiCluster left in clust to get the two closest clusters.
      # At the end of the loop the 'lowest_pair' will contain the ids of the two
      # closest clusters and the 'closest' variable will indicate the distance
      # between the two.
      clust.size.times do |i|
        (i + 1..clust.size - 1).each do |j|
          # calculate the distance between clusters **once**
          unless (distances.keys.member?([clust[i].id_num, clust[j].id_num]))
            distances[[clust[i].id_num, clust[j].id_num]] = distance.call(clust[i].vec, clust[j].vec)
          end
          
          d = distances[[clust[i].id_num, clust[j].id_num]]
          if d < closest
            closest = d
            lowest_pair = [i,j]
          end
        end
      end
      
      # calculate the average of the two clusters
      merge_vec = (0..clust[0].vec.size - 1).map do |i|
        (clust[lowest_pair[0]].vec[i] + clust[lowest_pair[1]].vec[i]) / 2.0
      end

      # create the new cluster
      clust << BiCluster.new(merge_vec, 
                             current_cluster_id, 
                             clust[lowest_pair[0]],
                             clust[lowest_pair[1]],
                             closest)
                             
      # cluster IDs not in the original set are negative
      current_cluster_id -= 1
      clust.delete_at(lowest_pair[1])
      clust.delete_at(lowest_pair[0])
    end

    clust.first
  end
  
  def self.print_cluster(cluster, labels=nil, n=0)
    print(' ' * n)
    if cluster.id_num < 0
      puts '-'
    else
      if labels.nil?
        puts cluster.id_num
      else
        puts labels[cluster.id_num]
      end
    end
    
    print_cluster(cluster.left, labels, n + 1) unless cluster.left.nil?
    print_cluster(cluster.right, labels, n + 1) unless cluster.right.nil?
  end
  
  # Rotate a given matrix by swapping columns and rows
  def self.rotate_matrix(data)
    new_data = []
    data.size.times do |i|
      new_row = []
      data.size.times do |j|
        new_row << data[j][i] 
      end
      new_data << new_row
    end
    
    new_data
  end
  
  ##
  # Computes a k-means cluster.
  # === Arguments
  # <tt>rows</tt>: The data to cluster
  # <tt>k</tt>: The k-factor for clustering
  # <tt>distance</tt>: A function/block to calculate distance (def. +Clusters.pearson+)
  def self.kcluster(rows, k=4, &distance)
    distance = lambda { |v1, v2| Clusters.pearson(v1, v2) } unless distance
    # Determine max and min values for each row
    ranges = []
    rows.first.size.times do |i|
      column = rows.map { |row| row[i] }
      ranges[i] = [column.min, column.max]
    end
    
    # Create 'k' randomly placed centroids
    clusters = []
    k.times do |j|
      clusters[j] = []
      rows.first.size.times do |i|
        clusters[j] << (rand * (ranges[i][1] - ranges[i][0]) + ranges[i][0])
      end
    end
    
    best_matches, last_matches = nil, nil

    99.times do |t|
      best_matches = []
      k.times { |i| best_matches[i] = [] }
      
      # find which centroid is the closest for each row
      rows.each_with_index do |row, j|
        best_match = 0
        k.times do |i|
          d = distance.call(clusters[i], row)
          if d < distance.call(clusters[best_match], row)
            best_match = i
          end
        end

        best_matches[best_match] << j
      end

      # if the results are the same as last time, this is complete
      break if best_matches == last_matches
      last_matches = best_matches
      
      # Move the centroids to the average of their members
      k.times do |i|
        avgs = [0.0] * rows.first.size
        if (best_matches[i].size > 0)
          best_matches[i].each do |rowid|
            rows[rowid].each_with_index do |e, m|
              avgs[m] += e
            end
          end
          
          avgs.each do |avg|
            avg /= best_matches[i].size
          end
          
          clusters[i] = avgs
        end
      end
    end
    
    best_matches
  end

  ##
  # Computes the Tanimoto distance (the ratio of the intersection of the 
  # vectors to the union of the vectors) between two vectors
  def self.tanimoto(v1, v2)
    c1, c2, shr = 0, 0, 0
    v1.size.times do |i|
      c1 += 1 if v1[i] != 0
      c2 += 1 if v2[i] != 0
      shr += 1 if v1[i] != 0 and v2[i] != 0
    end
    return 1.0 - (shr.to_f / (c1 + c2 - shr))
  end
  
  ##
  # multidimensional scaling
  # Nodes are placed randomly in 2D space. We calculate the distance
  # between a node and other nodes and correct for error. We do
  # this several times until the error correction becomes negligable.
  # === arguments
  # <tt>data</tt>: The data rows to scale
  # <tt>rate</tt>:
  # <tt>distance</tt>: The distance calculation function/block (def +Clusters.pearson+)
  def self.scaledown(data, rate=0.01, &distance)
    distance = lambda { |v1, v2| Clusters.pearson(v1, v2) } unless distance
    n = data.size
    
    # The real distances between every pair of itmes
    realdist = (0...n).map do |i|
      (0...n).map do |j|
        distance.call(data[i], data[j])
      end
    end
    
    outer_sum = 0.0
    
    # Randomly initialize the starting points of the locations in 2D
    loc = [[rand, rand]] * n
    fake_dist = [[0.0] * n] * n
    
    last_error = nil
    999.times do |m|
      # Find projected distances
      n.times do |i|
        n.times do |j|
          sum = (0..loc[i].size - 1).inject(0) do |memo, x|
            memo + (loc[i][x] - loc[j][x]) ** 2
          end
          fake_dist[i][j] = Math.sqrt(sum)
        end
      end
      
      # Move points
      grad = [[0.0, 0.0]] * n
      
      total_error = 0
      n.times do |k|
        n.times do |j|
          next if j == k
          # The error is percent difference between the distances
          error_term = (fake_dist[j][k] - realdist[j][k]) / realdist[j][k]
          
          # Each point needs to be moved away from or towards the other
          # piont in proportion to how much error it has
          grad[k][0] += ((loc[k][0] - loc[j][0]) / fake_dist[j][k]) * error_term
          grad[k][1] += ((loc[k][1] - loc[j][1]) / fake_dist[j][k]) * error_term
          
          # Keep track of the total error
          total_error += error_term.abs
        end
      end
      
      puts total_error
      
      # If the answer got worse by moving the points, we are done
      break if last_error and last_error < total_error
      last_error = total_error
      
      # Move each of the points by learning rate times the gradient
      n.times do |k|
        loc[k][0] -= rate * grad[k][0]
        loc[k][1] -= rate * grad[k][1]
      end
    end
    
    return loc
  end
  
  # A sub-module for drawing graphs
  module Graphs
    require "rubygems"
    require "RMagick"
    
    include Magick
    
    def self.get_height(cluster)
      if cluster.right.nil? and cluster.left.nil?
        1
      else
        get_height(cluster.left) + get_height(cluster.right)
      end
    end
    
    def self.get_depth(cluster)
      if cluster.left.nil? and cluster.right.nil?
        0
      else
        [get_depth(cluster.left), get_depth(cluster.right)].max + cluster.distance
      end
    end
    
    def self.draw_dendogram(cluster, labels, file='clusters.png')
      height = get_height(cluster) * 20
      width = 2400.to_f
      depth = get_depth(cluster)
      scaling = (width - 150) / depth

      img = Image.new(width, height) {
        self.background_color = 'white'
      }
      
      draw = Draw.new
      draw.font = '/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf'
      draw.line(0, height / 2, 10, height / 2)

      # Draw the first node 
      draw_node(draw, cluster, 10, height / 2, scaling, labels)
      draw.draw(img)
      img.write(file)
    end
    
    def self.draw_node(draw, cluster, x, y, scaling, labels)
      if (cluster.id_num < 0)
        h1 = get_height(cluster.left) * 20
        h2 = get_height(cluster.right) * 20
        top = y - (h1 + h2) / 2
        bottom = y + (h1 + h2) / 2
        
        # line length
        line_length = cluster.distance * scaling

        # Vertical line from cluster to it's children
        draw.line(x, top + h1 /2 , x, bottom - h2/ 2)

        # Horizontal line to left item 
        draw.line(x, top + h1 / 2, x + line_length, top + h1 / 2)

        # Horizontal line to right item 
        draw.line(x, bottom - h2 / 2, x + line_length, bottom - h2 / 2)

        # Call the function to draw the left and right nodes 
        draw_node(draw, cluster.left, x+line_length, top+h1/2, scaling, labels) 
        draw_node(draw, cluster.right, x+line_length, bottom-h2/2, scaling, labels)
      else
        # draw the node for the endpoint
        draw.text(x, y + 4, labels[cluster.id_num]) 
      end
    end
    
    # 3.8
    def self.draw2d(data, labels, file='/tmp/mds2d.png')
      img = Image.new(2000, 2000) {
        self.background_color = 'white'
      }
      
      draw = Draw.new
      draw.font = '/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf'

      data.each_with_index do |d, i|
        x = (d[0] + 0.5) * 1000
        y = (d[1] + 0.5) * 1000
        draw.text(x, y, labels[i])
      end
      
      draw.draw(img)
      img.write(file)
    end
  end
end

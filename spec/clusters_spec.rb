require File.dirname(__FILE__) + '/../lib/clusters'

describe Clusters, "h_cluster function" do
  it "should return a cluster of the two vectors from an initial input of two vectors" do
    rows = [
      [1, 2, 3],
      [4, 5, 6]
    ]
    
    cluster = Clusters.h_cluster(rows) do |v1, v2|
      Clusters.pearson(v1, v2)
    end
    
    cluster.left.vec.should == [1, 2, 3]
    cluster.right.vec.should == [4, 5, 6]
    cluster.vec.should == [2.5, 3.5, 4.5]
  end
  
  it "should return a cluster with one-digit-value vectors on one side, and multi-digit vectors on the other" do
    rows = [
      [1, 2, 3],
      [4, 5, 6],
      [10, 11, 12]
    ]
    
    cluster = Clusters.h_cluster(rows) do |v1, v2|
      Clusters.pearson(v1, v2)
    end
    
    cluster.right.vec.should == [2.5, 3.5, 4.5] # the average of the first two vectors
    cluster.left.vec.should == [10, 11, 12]
    cluster.vec.should == [6.25, 7.25, 8.25]
  end
end

describe Clusters, "rotate_matrix function" do
  it "should swap the rows and the columns in a matrix" do
    data = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ]
    
    rotated = Clusters.rotate_matrix(data)
    rotated.should == [
      [1, 4, 7],
      [2, 5, 8],
      [3, 6, 9]
    ]
  end
end

describe Clusters, "kcluster function" do
  it "should cluster blogdata correctly" do
    blognames, words, data = Clusters.readfile(File.dirname(__FILE__) + '/../data/blogdata.txt')
    
    kclust = Clusters.kcluster(data[0..10], 5) do |v1, v2|
      Clusters.pearson(v1, v2)
    end
    kclust.should_not be_empty
    kclust.size.should == 5

    # An id should only occur in one cluster
    kclust.each_with_index do |cluster, i|
      if i < kclust.size - 1
        (cluster & kclust[i + 1]).should be_empty
      end
    end
  end
end

describe Clusters, "tanimoto function" do
  it "should return 0.0 for matching sets" do
    v1 = [1, 0, 1]
    
    Clusters.tanimoto(v1, v1).should == 0.0
  end
  
  it "should return 0 for complete disjoint vectors" do
    v1 = [1, 0, 1]
    v2 = [0, 1, 0]
    
    Clusters.tanimoto(v1, v2).should == 1.0
  end
  
  it "should return a number between 0.0 and 1.0 for vectors with overlap" do
    v1 = [1, 0, 1]
    v2 = [1, 1, 1]
    
    tanimoto = Clusters.tanimoto(v1, v2)
    tanimoto.should > 0.0
    tanimoto.should < 1.0
  end
end
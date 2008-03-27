require File.dirname(__FILE__) + '/../lib/recommendation'

describe "Recommendations" do
  before(:each) do
    @prefs = {
      'Lisa Rose' => {
        'Lady in the Water' => 2.5, 
        'Snakes on a Plane' => 3.5, 
        'Just My Luck' => 3.0, 
        'Superman Returns' => 3.5, 
        'You, Me and Dupree' => 2.5, 
        'The Night Listener' => 3.0
      }, 
      'Gene Seymour' => {
        'Lady in the Water' => 3.0, 
        'Snakes on a Plane' => 3.5, 
        'Just My Luck' => 1.5, 
        'Superman Returns' => 5.0, 
        'The Night Listener' => 3.0, 
        'You, Me and Dupree' => 3.5
      }, 
      'Michael Phillips' => {
        'Lady in the Water' => 2.5, 
        'Snakes on a Plane' => 3.0, 
        'Superman Returns' => 3.5, 
        'The Night Listener' => 4.0
      }, 
      'Claudia Puig' => {
        'Snakes on a Plane' => 3.5, 
        'Just My Luck' => 3.0, 
        'The Night Listener' => 4.5, 
        'Superman Returns' => 4.0, 
        'You, Me and Dupree' => 2.5
      }, 
      'Mick LaSalle' => {
        'Lady in the Water' => 3.0, 
        'Snakes on a Plane' => 4.0, 
        'Just My Luck' => 2.0, 
        'Superman Returns' => 3.0, 
        'The Night Listener' => 3.0, 
        'You, Me and Dupree' => 2.0
      }, 
      'Jack Matthews' => {
        'Lady in the Water' => 3.0, 
        'Snakes on a Plane' => 4.0, 
        'The Night Listener' => 3.0, 
        'Superman Returns' => 5.0, 
        'You, Me and Dupree' => 3.5
      }, 
      'Toby' => {
        'Snakes on a Plane' =>4.5,
        'You, Me and Dupree' =>1.0,
        'Superman Returns' =>4.0
      }
    } 
  end

  describe "Euclidian distance between Lisa Rose and Gene Seymour" do
    before(:each) do
      @lisa = Recommendation::SimEuclid.new(@prefs, 'Lisa Rose')
      @gene = Recommendation::SimEuclid.new(@prefs, 'Gene Seymour')
    end

    it "should compute distance correctly" do
      @lisa.compute('Gene Seymour').should be_close(0.294, 0.005)
      @gene.compute('Mick LaSalle').should be_close(0.277, 0.005)
      # @lisa.compute('Jack Matthews').should be_close(0.340, 0.005)
    end
  end

  describe "Pearson distance calculation" do
    before(:each) do
      @lisa = Recommendation::SimPearson.new(@prefs, 'Lisa Rose')
    end

    it "should calculate correct distance" do
      @lisa.compute('Gene Seymour').should be_close(0.396, 0.005)
    end
  end

  describe "Match" do
    describe "top_matches" do
      it "should return top 3 critics most similar to Toby" do
        @toby = Recommendation::Match.new(@prefs, 'Toby')
        matches = @toby.top_matches
        matches.size.should == 3
    
        matches[0][0].should be_close(0.991, 0.005)
        matches[0][1].should == 'Lisa Rose'
    
        matches[1][0].should be_close(0.924, 0.005)
        matches[1][1].should == 'Mick LaSalle'
    
        matches[2][0].should be_close(0.893, 0.005)
        matches[2][1].should == 'Claudia Puig'
      end
    end
    
    describe "get_recommendations" do
      it "should recommend the correct movies for Toby using default Pearson distance" do
        @toby = Recommendation::Match.new(@prefs, 'Toby')
        recs = @toby.getRecommendations

        recs.size.should == 3
        recs[0][0].should be_close(3.347, 0.005)
        recs[0][1].should == 'The Night Listener'
    
        recs[1][0].should be_close(2.832, 0.005)
        recs[1][1].should == 'Lady in the Water'
    
        recs[2][0].should be_close(2.530, 0.005)
        recs[2][1].should == 'Just My Luck'
      end
  
      it "should recommend the correct movies for Toby using Euclidean distance" do
        @toby = Recommendation::Match.new(@prefs, 'Toby', Recommendation::SimPearson)
        recs = @toby.getRecommendations
    
        recs.size.should == 3
    
        recs[0][0].should be_close(3.477895, 0.2)
        recs[0][1].should == 'The Night Listener'
    
        recs[1][0].should be_close(2.832254, 0.2)
        recs[1][1].should == 'Lady in the Water'
    
        recs[2][0].should be_close(2.530980, 0.2)
        recs[2][1].should == 'Just My Luck'
      end
    end


  end
end
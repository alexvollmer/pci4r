class Recommendation

# init this class with a preference array, 
#   eg: {
#         'sandro' => { 'movie1' => 5, 'movie2' => 4, 'movie3' => 3 },
#         'alex'  => { 'movie2' => 3 }
#
#       }
# 
# a person ( 'sandro' ),
# and (optional)  the name of a Similarity class Object ( eg: SimPearson.new) 


   def initialize(prefs,person,similarity = SimPearson)
     @prefs, @person, @similarity = prefs, person, similarity.new(prefs,person)
   end
   
# == RANKING ==
# it returns the n people closest in choiches to me    
   
   def top_matches(n=3)
     
     scores = Array.new
     
     @prefs.each_pair do |key,value|
       if key != @person
         scores << [@similarity.compute(key),key]
       end
     end
     
     (scores.sort!.reverse!)[0..n]
     
   end

# == RECOMMENDATIONS ==
# it returns all the elements that you have not ranked ordered using 
# other users scores weightened by the distance between that user's rankings and yours   
   
   def getRecommendations()
     totals=Hash.new(0)
     simSum=Hash.new(0)
     
     
     @prefs.each_pair do |other,ranks|
       
       # next if it's me
       next if other == @person
       
       # check the affinity 
       sim = @similarity.compute(other)
       
       # next if no affinity
       next if sim <= 0
       
       # for each unranked element
       ranks.each_pair do |name,rank|
         if !@prefs[@person].include?(name) or @prefs[@person].length == 0
           
           totals[name] += rank * sim
           simSum[name] += sim
           
         end
       end  
     end
     
     # Array creation
     totals.to_a.collect do |e|
       [e[1]/simSum[e[0]],e[0]]
     end.sort do |a,b|
       b[0] <=> a[0]
     end
     
   end
   
end


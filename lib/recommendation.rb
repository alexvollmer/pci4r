module Recommendation

  class Match

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
     
       (scores.sort!.reverse!)[0...n]
     
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

  class Similarity

  # init this class using a preference array and a person

  	def initialize(prefs, person) 
      @prefs, @person = prefs, person
  	end

  # == UTILITY ==
  # it returns all the elements in common between two subsets

  	def elements_in_common(subs1,subs2)
  	  si = Hash.new

  	  # recupero gli elementi in comune
  	  subs1.each_pair do |item,value|
  	    si[item] = 1 if subs2.include?(item)
  	  end
  
  	  return si
  	end

  end

  class SimEuclid < Similarity

      # Ritorna la distanza euclidea tra due elementi
      def compute(person2)

        si = elements_in_common(@prefs[@person],@prefs[person2])

        # se non ce ne sono ritorno 0
        return 0 if si.length == 0

        # faccio la somma del quadrato delle differenze delle valutazioni
        # delle due persone
        sum_of_squares = 0.0
        @prefs[@person].each_pair do |key,value|
          sum_of_squares += (@prefs[@person][key].to_f - @prefs[person2][key].to_f) ** 2
        end

        # faccio in modo che il risultato sia compreso tra 0 (nessuna correlazione)
        # a 1 (massima correlazione)
  
        # La nuova formula che mi ha passato rb
        1/(1+ Math.sqrt(sum_of_squares))

      end
 
  end

  class SimPearson < Similarity

  # ritorna la distanza di Pearson tra due elementi
   def compute(person2)
   
     si = elements_in_common(@prefs[@person],@prefs[person2])
   
     # recupero la lunghezza degli elem in comune
     n = si.length
   
     # se non ci sono elementi in comune ritorno 0
     return 0 if n == 0
   
     # sommo i valori degli elementi in comune, i loro quadrati,
     # i loro prodotti
     sum1 = sum2 = sum1Sq = sum2Sq = pSum = 0.0
   
     si.each do |item|
       sum1   += @prefs[@person][item[0]]
       sum2   += @prefs[person2][item[0]]
       sum1Sq += @prefs[@person][item[0]] ** 2
       sum2Sq += @prefs[person2][item[0]] ** 2
       pSum   += @prefs[person2][item[0]] * @prefs[@person][item[0]]
     end
   
     # calcolo il punteggio di Pearson
     num = pSum - ( ( sum1 * sum2 ) / n )
     den = Math.sqrt( ( sum1Sq - ( sum1 ** 2 ) / n ) * ( sum2Sq - ( sum2 ** 2 ) / n ) )
   
     return 0 if den == 0
   
     num / den
   
   end
 
  end
end
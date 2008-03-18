
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
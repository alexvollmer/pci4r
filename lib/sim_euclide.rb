
class SimEuclide < Similarity

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

 

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
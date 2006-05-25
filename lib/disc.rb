class Disc
  attr_accessor :number, :tracks, :number_of_tracks
  
  def initialize
    @tracks = []
  end
  
  def number_of_tracks
    @number_of_tracks = @tracks.nitems
  end
end
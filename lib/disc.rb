class Disc
  attr_accessor :album, :number, :tracks, :number_of_tracks
  
  def initialize
    @tracks = []
  end
  
  def number_of_tracks_loaded
    @tracks.nitems
  end
end
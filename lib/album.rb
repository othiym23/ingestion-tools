class Album
  attr_accessor :name, :artist_name
  attr_accessor :discs, :number_of_discs
  attr_accessor :genre, :release_date, :compilation
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  
  def initialize
    @discs = []
  end
  
  def number_of_tracks
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks }
  end
  
  def number_of_tracks_loaded
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks_loaded }
  end
  
  def number_of_discs_loaded
    @discs.compact.size
  end
end
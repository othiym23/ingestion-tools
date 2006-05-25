class Album
  attr_accessor :name, :artist_name, :discs
  attr_accessor :number_of_discs, :release_date, :compilation
  attr_accessor :genre, :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  
  def initialize
    @discs = []
  end
  
  def number_of_tracks
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks }
  end
end
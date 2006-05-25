$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'track'
require 'track_metadata'

class TrackDao
  attr_accessor :path, :filename, :id3
  
  def initialize(path)
    @path = TrackPathMetadata.new(path)
    @filename = TrackFilenameMetadata.new(path)
    @id3 = TrackId3Metadata.new(path)
  end

  def load_track(path)
    track = Track.new(path)
    
    track.album_name =
      @id3.album_name ||
      @filename.album_name ||
      @path.album_name
    track.name =
      @id3.track_name ||
      @filename.track_name
    track.artist_name =
      @id3.artist_name ||
      @filename.artist_name ||
      @path.artist_name

    track.sequence =
      (@id3.sequence || 
       @filename.sequence).to_i

    track.genre = @id3.genre
    track.comment = @id3.comment
    track.encoder = @id3.encoder
    
    track
  end
  
  def disc_number
    (@path.disc_number ||
     @id3.disc_number ||
     1).to_i
  end
  
  def number_of_discs_in_set
    (@id3.max_disc_number ||
     1).to_i
  end
  
  def number_of_tracks_on_disc
    @id3.max_sequence.to_i
  end
end
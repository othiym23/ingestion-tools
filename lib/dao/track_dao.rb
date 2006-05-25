$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'track'
require 'track_metadata'

class TrackDao
  attr_accessor :path, :filename, :id3v2
  
  def initialize(path)
    @path = TrackPathMetadata.new(path)
    @filename = TrackFilenameMetadata.new(path)
    @id3v2 = TrackId3V2Metadata.new(path)
  end

  def load_track(path)
    track = Track.new(path)
    
    track.album_name =
      @id3v2.album_name ||
      @filename.album_name ||
      @path.album_name
    track.name =
      @id3v2.track_name ||
      @filename.track_name
    track.artist_name =
      @id3v2.artist_name ||
      @filename.artist_name ||
      @path.artist_name

    track.disc_number =
      (@path.disc_number ||
       @id3v2.disc_number ||
       1).to_i
    track.max_disc_number =
      (@id3v2.max_disc_number ||
       1).to_i
    track.sequence =
      (@id3v2.sequence || 
       @filename.sequence).to_i
    track.max_sequence = @id3v2.max_sequence.to_i

    track.genre = @id3v2.genre
    track.comment = @id3v2.comment
    track.encoder = @id3v2.encoder
    
    track
  end
end
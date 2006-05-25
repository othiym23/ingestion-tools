require File.join(File.dirname(__FILE__), 'track_metadata')

class Track
  attr_accessor :album_name, :name, :artist_name
  attr_accessor :disc_number, :sequence, :max_sequence
  attr_accessor :genre, :comment, :encoder, :musicbrainz_artist_id
  
  def initialize(path)
    path_metadata = TrackPathMetadata.new(path)
    filename_metadata = TrackFilenameMetadata.new(path)
    id3v2_metadata = TrackId3V2Metadata.new(path)
    
    @name = id3v2_metadata.track_name || filename_metadata.track_name
    @album_name = id3v2_metadata.album_name || filename_metadata.album_name || path_metadata.album_name
    @artist_name = id3v2_metadata.artist_name || filename_metadata.artist_name || path_metadata.artist_name
    @sequence = id3v2_metadata.sequence || filename_metadata.sequence.to_i
    @max_sequence = id3v2_metadata.max_sequence
    @disc_number = path_metadata.disc_number.to_i || id3v2_metadata.disc_number
    @genre = id3v2_metadata.genre
    @comment = id3v2_metadata.comment
    @encoder = id3v2_metadata.encoder
  end
end
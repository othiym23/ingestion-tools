require 'track'
require 'track_metadata'

class TrackDao
  attr_accessor :path, :filename, :id3
  
  def initialize(path)
    @path = TrackPathMetadata.new(path)
    @filename = TrackFilenameMetadata.new(path)
    @id3 = TrackId3Metadata.load_from_path(path)
  end

  def load_track(path)
    track = Track.new(path)
    
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
    track.release_date = @id3.release_date
    track.unique_id = @id3.unique_id
    track.musicbrainz_artist_id = @id3.musicbrainz_artist_id
    
    track.set_remix!
    track.set_featured_artists!
    track.canonicalize_encoders!
    track.canonicalize_comments!
    
    track
  end
  
  def album_name
    @id3.album_name ||
    @filename.album_name ||
    @path.album_name
  end

  def disc_number
    (@id3.disc_number ||
     @path.disc_number ||
     1).to_i
  end
  
  def number_of_discs_in_set
    (@id3.max_disc_number ||
     1).to_i
  end
  
  def number_of_tracks_on_disc
    @id3.max_sequence.to_i
  end
  
  def musicbrainz_album_artist_id
    return @id3.musicbrainz_album_artist_id
  end
  
  def musicbrainz_album_id
    return @id3.musicbrainz_album_id
  end
  
  def musicbrainz_album_type
    return @id3.musicbrainz_album_type
  end
  
  def musicbrainz_album_status 
    return @id3.musicbrainz_album_status
  end
  
  def musicbrainz_album_release_country
    return @id3.musicbrainz_album_release_country
  end
end
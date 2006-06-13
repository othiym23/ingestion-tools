require 'path_utils'

require 'track'
require 'track_metadata'

class TrackDao
  attr_accessor :path, :filename, :id3
  attr_reader :track
  
  def initialize(path)
    @path = TrackPathMetadata.load_from_path(path)
    @filename = TrackFilenameMetadata.load_from_path(path)
    @id3 = TrackId3Metadata.load_from_path(path)
    
    @track = Track.new(path)
    
    @track.name = @id3.track_name || @filename.track_name
    @track.remix = @id3.remix_name
    @track.artist_name = @id3.artist_name || @filename.artist_name || @path.artist_name
    @track.sequence = (@id3.sequence || @filename.sequence).to_i

    @track.genre = @id3.genre
    @track.comment = @id3.comment
    @track.encoder = @id3.encoder
    @track.release_date = @id3.release_date
    @track.unique_id = @id3.unique_id
    @track.musicbrainz_artist_id = @id3.musicbrainz_artist_id
    
    @track.sort_order = @id3.track_sort_order
    @track.artist_sort_order = @id3.artist_sort_order
    @track.featured_artists = @id3.featured_artists || []
    @track.image = @id3.album_image
    
    @track.set_remix!
    @track.set_featured_artists!
    @track.capitalize_names!
    @track.set_sort_order!
    @track.canonicalize_encoders!
    @track.canonicalize_comments!
  end
  
  def TrackDao.save(track)
    id3 = TrackId3Metadata.load_from_track(track)
    id3.save
  end
  
  def TrackDao.archive_mp3_from_track_dao(archive_root, track_dao)
    source_path = track_dao.track.path
    
    id3 = populate_id3_metadata_from_dao(track_dao)
    
    new_path = File.join(archive_root, id3.canonical_full_path)
    PathUtils.safe_move(source_path, new_path)
    id3.full_path = new_path

    id3.save
  end
  
  def TrackDao.archive_mp3_from_track(archive_root, track)
    source_path = track.path
    
    id3 = TrackId3Metadata.load_from_track(track)
    
    new_path = File.join(archive_root, id3.canonical_full_path)
    PathUtils.safe_move(source_path, new_path)
    id3.full_path = new_path

    id3.save
  end
  
  def album_name
    @id3.album_name ||
    @filename.album_name ||
    @path.album_name
  end
  
  def album_subtitle
    @id3.album_subtitle
  end
  
  def album_version
    @id3.album_version
  end
  
  # HEURISTIC: to keep things like loose MP3 directories from going ape crazy,
  # create a hash based on munged values for the artist name from the
  # path and the album name, whatever it may be
  def album_bucket
    (@path.artist_name.upcase << '|' << album_name.upcase).gsub(' ', '')
  end
  
  def compilation?
    if !@id3.compilation.nil? && @id3.compilation != ''
      @id3.compilation
    else
      @path.compilation?
    end
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
  
  def album_sort_order
    @id3.album_sort_order
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

  private
  
  def self.populate_id3_metadata_from_dao(dao)
    id3 = TrackId3Metadata.new
    
    track = dao.track
    
    id3.album_name = dao.album_name
    id3.album_subtitle = dao.album_subtitle
    id3.album_version = dao.album_version
    id3.disc_number = dao.disc_number
    id3.max_disc_number = dao.number_of_discs_in_set

    id3.max_sequence = dao.number_of_tracks_on_disc
    
    id3.compilation = dao.compilation?

    id3.musicbrainz_album_id = dao.musicbrainz_album_id
    id3.musicbrainz_album_type = dao.musicbrainz_album_type
    id3.musicbrainz_album_status = dao.musicbrainz_album_status
    id3.musicbrainz_album_release_country = dao.musicbrainz_album_release_country
    id3.musicbrainz_album_artist_id = dao.musicbrainz_album_artist_id
    
    id3.track_name = track.reconstituted_name
    id3.remix_name = track.remix
    id3.artist_name = track.artist_name
    id3.featured_artists = track.featured_artists
    id3.album_image = track.image
    id3.sequence = track.sequence
    
    id3.comment = track.comment
    id3.encoder = track.encoder.join(' / ') if track.encoder
    
    id3.genre = track.genre
    id3.release_date = track.release_date
    
    id3.unique_id = track.unique_id
    id3.musicbrainz_artist_id = track.musicbrainz_artist_id
    
    id3.track_sort_order = track.sort_order
    id3.artist_sort_order = track.artist_sort_order
    
    id3
  end
end
require 'path_utils'
require 'album'
require 'disc'
require 'dao/track_dao'

class AlbumAlreadyExistsException < IOError; end

class AlbumDao
  attr_accessor :archive_root
  
  def initialize(archive_root)
    @archive_root = archive_root
  end
  
  def AlbumDao.load_albums_from_paths(paths)
    albums = {}
    paths.each do |path|
      track_dao = TrackDao.new(path)
      track = track_dao.track

      album_name = track_dao.album_name
      if albums[album_name].nil?
        new_album = Album.new
        new_album.name = album_name
        new_album.number_of_discs = track_dao.number_of_discs_in_set
        albums[album_name] = new_album
      end

      album = albums[album_name]
      album.musicbrainz_album_artist_id = track_dao.musicbrainz_album_artist_id if track_dao.musicbrainz_album_artist_id
      album.musicbrainz_album_id = track_dao.musicbrainz_album_id if track_dao.musicbrainz_album_id
      album.musicbrainz_album_type = track_dao.musicbrainz_album_type if track_dao.musicbrainz_album_type
      album.musicbrainz_album_status = track_dao.musicbrainz_album_status if track_dao.musicbrainz_album_status
      album.musicbrainz_album_release_country = track_dao.musicbrainz_album_release_country if track_dao.musicbrainz_album_release_country
      album.compilation = true if track_dao.compilation?
      album.sort_order = track_dao.album_sort_order if track_dao.album_sort_order
      
      disc_number = track_dao.disc_number
      if album.discs[disc_number].nil?
        new_disc = Disc.new
        new_disc.number = disc_number
        album.discs[disc_number] = new_disc
        new_disc.album = album
        new_disc.number_of_tracks = track_dao.number_of_tracks_on_disc
      end
      disc = album.discs[disc_number]
      track.disc = disc

      disc.tracks << track
    end

    albums.each do |album_name,album|
      artists = []
      genres = []
      years = []
      musicbrainz_artist_ids = []
      images = []
      
      album.set_mixer!
      album.set_encoder_from_comments!
      album.find_hidden_soundtrack!
      album.set_sort_order!
      
      album.discs.compact.each do |disc|
        disc.tracks.each do |track|
          artists << track.artist_name
          genres << track.genre
          years << track.release_date
          musicbrainz_artist_ids << track.musicbrainz_artist_id
          images << track.image
        end
      end
      
      # HEURISTIC: promote track-level artists to album level, finding any secret
      # compilations to boot
      #
      # TODO: correctly handle split albums with "Artist 1 / Artist 2" titles
      if album.compilation
        if 1 == artists.compact.uniq.size
          album.artist_name = artists.first
          album.compilation = false
        else
          album.artist_name = 'Various Artists'
        end
      else
        if 1 < artists.compact.uniq.size
          album.artist_name = "Various Artists"
          album.compilation = true
        else
          album.artist_name = artists.first
        end
      end
      
      # HEURISTIC: promote genres to album level, choosing the most frequent
      # genre if there's more than one
      if 1 == genres.compact.uniq.size
        album.genre = genres.first
      else
        popularity_contest = []
        genres.compact!
        genres.uniq.each do |genre|
          popularity_contest << [genre, genres.size - (genres - [genre]).size]
        end
        album.genre = popularity_contest.sort{|l,r| l[1] <=> r[1]}.last[0] if popularity_contest.size > 0
      end
      
      # HEURISTIC: promote track-level release year to album level, choosing
      # the latest date if there's a list
      if 1 == years.compact.uniq.size
        album.release_date = years.compact.first
      else
        album.release_date = years.compact.uniq.sort.last
      end
      
      # HEURISTIC: promote track-level MusicBrainz data to album level
      if 1 == musicbrainz_artist_ids.compact.uniq.size &&
        (album.musicbrainz_album_artist_id.nil? ||
         '' == album.musicbrainz_album_artist_id)
        album.musicbrainz_album_artist_id = musicbrainz_artist_ids.compact.uniq.first
      end
      
      # HEURISTIC: albums coming out of most rippers are only set to have 1 disc
      if !album.number_of_discs || (album.number_of_discs < album.number_of_discs_loaded)
        album.number_of_discs = album.number_of_discs_loaded 
      end
      
      # HEURISTIC: if we have any images for this album and some tracks are
      # lacking an image, assign them one arbitrarily
      if 1 <= images.compact.uniq.size
        album_image = images.compact.first
      end
      
      if album_image
        album.tracks.each do |track|
          track.image = album_image unless track.image
        end
      end
    end
    
    albums.values
  end
  
  def AlbumDao.save(album)
    album.tracks.each do
      TrackDao.save(track)
    end
  end
  
  def archive_album(album)
    if !already_in_archive?(album)
      album.tracks.each do |track|
        TrackDao.archive_mp3_from_track(@archive_root, track)
      end
      
      remove_empty_paths(album.tracks.collect{|track| track.path})
    else
      raise AlbumAlreadyExistsException.new("#{album.artist_name}: #{album.name} is already in the archive")
    end
  end
  
  private
  
  def already_in_archive?(album)
    raw_path_metadata = album.tracks.collect{|track| TrackPathMetadata.load_from_track(track)}.uniq
    
    raw_path_metadata.detect do |album_directory|
      canonical_path = album_directory.canonical_path
      dedisked_path = canonical_path.gsub(/ disc \d+/, '')
      
      PathUtils.album_ingested?(@archive_root, canonical_path) ||
      PathUtils.album_ingested?(@archive_root, dedisked_path)
    end
  end

  def remove_empty_paths(file_paths)
    source_roots = []
    album_dirs = []
    artist_dirs = []
    warnings = []

    file_paths.compact.each do |file|
      raise IOError.new("#{file} should have been moved!") if File.exists?(file)

      path_stack = File.dirname(file).split(File::SEPARATOR)
      album_dirs << File.join(path_stack[-2], path_stack.pop) # uses stack lookahead
      artist_dirs << path_stack.pop
      source_roots << File.join(path_stack)
    end
    
    source_roots = source_roots.uniq
    raise IOError.new("Holding directory mismatch for roots #{source_roots.join(", ")}!") if source_roots.size > 1
    source_root = source_roots.first
    
    album_dirs.uniq.each do |directory|
      full_path = File.join(source_root, directory)
      leftovers = Dir.glob(File.join(full_path, '*'))
      if 0 == leftovers.size
        Dir.delete(full_path)
      else
        leftover_files = leftovers.collect { |file| file.basename }
        warnings << "#{full_path} still contains #{leftovers.size} files: #{leftover_files.join(', ')}"
      end
    end
    
    artist_dirs.uniq.each do |directory|
      full_path = File.join(source_root, directory)
      if 0 == Dir.glob(File.join(full_path, '*')).size
        Dir.delete(full_path)
      end
    end
    
    warnings
  end
end
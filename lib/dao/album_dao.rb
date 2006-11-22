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

      album_bucket = track_dao.album_bucket
      if albums[album_bucket].nil?
        new_album = Album.new
        new_album.name = track_dao.album_name
        new_album.number_of_discs = track_dao.number_of_discs_in_set
        albums[album_bucket] = new_album
      end

      album = albums[album_bucket]
      # HEURISTIC: assign album-level MusicBrainz data to album level from
      # tracks; conflict-resolution scheme is to not resolve any conflicts
      # and let the MusicBrainz matcher figure out what we've got
      if track_dao.musicbrainz_album_artist_id &&
         '' != track_dao.musicbrainz_album_artist_id &&
         album.musicbrainz_album_artist_id.nil?

        album.musicbrainz_album_artist_id = track_dao.musicbrainz_album_artist_id
      end
      
      if track_dao.musicbrainz_album_id &&
         '' != track_dao.musicbrainz_album_id &&
         album.musicbrainz_album_id.nil?
        album.musicbrainz_album_id = track_dao.musicbrainz_album_id
      end
      
      if track_dao.musicbrainz_album_type &&
         '' != track_dao.musicbrainz_album_type &&
         album.musicbrainz_album_type.nil?
        album.musicbrainz_album_type = track_dao.musicbrainz_album_type
      end
      
      if track_dao.musicbrainz_album_status &&
         '' != track_dao.musicbrainz_album_status &&
         album.musicbrainz_album_status.nil?
        album.musicbrainz_album_status = track_dao.musicbrainz_album_status
      end
      
      if track_dao.musicbrainz_album_release_country &&
         '' != track_dao.musicbrainz_album_release_country &&
         album.musicbrainz_album_release_country.nil?
        album.musicbrainz_album_release_country = track_dao.musicbrainz_album_release_country
      end
      
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

    albums.each do |album_bucket,album|
      artists = []
      genres = []
      years = []
      musicbrainz_artist_ids = []
      images = []
      directories = []
      
      album.discs.compact.each do |disc|
        disc.tracks.each do |track|
          artists << track.artist_name
          genres << track.genre
          years << track.release_date
          musicbrainz_artist_ids << track.musicbrainz_artist_id
          images << track.image
          directories << File.dirname(track.path)
        end
      end
      
      # HEURISTIC: promote track-level artists to album level, finding any secret
      # compilations and split albums to boot
      if 1 == artists.compact.uniq.size
        album.artist_name = artists.compact.first
        album.compilation = false
      else
        actual_compilation = false
        artists.compact.uniq.each do |artist|
          actual_compilation = true if !album.name.match(/#{Regexp.quote(artist)}/)
        end
        
        if actual_compilation
          album.artist_name = 'Various Artists'
          album.compilation = true
        else
          album.artist_name = album.name
          album.compilation = false
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
      
      # HEURISTIC: promote track-level MusicBrainz artist to album level
      if 1 == musicbrainz_artist_ids.compact.uniq.size &&
        (!album.musicbrainz_album_artist_id.nil?
         '' != album.musicbrainz_album_artist_id)
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
      
      # HEURISTIC: an album can potentially be spread across multiple
      # directories. Choose the modification date of whichever one was
      # modified most recently.
      album.modification_date = directories.compact.uniq.map{|path|File.stat(path).mtime}.max
      album.non_media_files = load_non_media_files_from_paths(directories.compact.uniq)
      
      album.find_hidden_soundtrack!
      album.set_subtitle!
      album.set_mixer!
      album.set_version_name!
      album.capitalize_names!
      album.set_sort_order!
      album.set_encoder_from_comments!
    end
    
    albums.values
  end
  
  def AlbumDao.reload_album_from_files(album)
    album_paths = album.discs.compact.collect{|disc| disc.tracks.collect{|track| track.path}}
    AlbumDao.load_albums_from_paths(album_paths.flatten).first
  end
  
  def AlbumDao.load_non_media_files_from_paths(paths)
    non_media_files = []
    
    paths.each do |path|
      non_media_files += Dir.glob(File.join(path, '**', '*')).select{ |entry| File.file?(entry) && '.mp3' != File.extname(entry) }
    end
    
    non_media_files.compact.uniq
  end
  
  def AlbumDao.save(album)
    album.tracks.each do |track|
      TrackDao.save(track)
    end
  end
  
  def AlbumDao.purge(album)
    raise Error.new("Have the wrong class, boss!") if !album.respond_to?(:cached_album)
    raise Error.new("Can't purge without the cached album!") unless album.cached_album
    
    purge_cached_album(album.cached_album)
    
    album.non_media_files.each do |path|
      MediaPathDao.purge_cached_path(path)
    end
  end
  
  def AlbumDao.merge_albums(master, subject)
    raise Error.new("Can't merge without the cached album!") unless master.cached_album && subject.cached_album
    AlbumDao.merge_cached_albums(master.cached_album, subject.cached_album)
  end

  def archive_album(album)
    if !already_in_archive?(album)
      album_directories = []
      moved_files = []
      album.tracks.each do |track|
        moved_files << track.path
        album_directories << File.dirname(TrackDao.archive_mp3_from_track(@archive_root, track))
      end
      
      non_mp3_dest_folder = album_directories.compact.uniq.sort.first
      
      album.non_media_files.each do |non_media_file_path|
        moved_files << non_media_file_path
        archive_non_audio_file(non_mp3_dest_folder, non_media_file_path)
      end
      
      moved_files.each do |file|
        File.delete(file)
      end

      remove_empty_paths(moved_files)
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

  def archive_non_audio_file(dest_dir, source_path)
    new_path = File.join(dest_dir, File.basename(source_path))
    PathUtils.safe_copy(source_path, new_path)
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

      # I hate these stupid things
      File.delete(File.join(full_path, '.DS_Store')) if File.exists?(File.join(full_path, '.DS_Store'))

      leftovers = Dir.entries(full_path).reject {|filename| filename == '.' || filename == '..'}
      if 0 == leftovers.size
        Dir.delete(full_path)
      else
        warnings << "#{full_path} still contains #{leftovers.size} files: #{leftovers.join(', ')}"
      end
    end
    
    artist_dirs.uniq.each do |directory|
      full_path = File.join(source_root, directory)

      # I hate these stupid things
      File.delete(File.join(full_path, '.DS_Store')) if File.exists?(File.join(full_path, '.DS_Store'))

      if 0 == Dir.entries(full_path).reject {|filename| filename == '.' || filename == '..'}.size
        Dir.delete(full_path)
      end
    end
    
    warnings
  end
end
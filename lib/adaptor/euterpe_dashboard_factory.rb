$: << File.expand_path(File.join(File.dirname(__FILE__), '../../../../rails/euterpe-dashboard'))

require 'rubygems'
require 'active_record'

require 'app/models/artist'
require 'app/models/media_path'
require 'app/models/genre'
require 'app/models/album'
require 'app/models/disc'
require 'app/models/disc_bucket'
require 'app/models/track'

require 'dao/album_dao'
require 'dao/track_dao'

class GenreDao
  def GenreDao.find_genre(entity_with_genre)
    genre_string = entity_with_genre.genre
    genre_string = '<unknown>' unless genre_string && '' != genre_string

    db_genre = Euterpe::Dashboard::Genre.find_by_name(genre_string)
    unless db_genre
      db_genre = Euterpe::Dashboard::Genre.new
      db_genre.name = genre_string
      db_genre.save
    end
    
    db_genre
  end
end

class MediaPathDao
  def MediaPathDao.cache_file(filename)
    record_changed = false
    
    file_record = Euterpe::Dashboard::MediaPath.find_by_path(filename)
    
    unless file_record
      file_record = Euterpe::Dashboard::MediaPath.new
      file_record.path = filename
    end
    
    unless file_record.file_updated_on == File.stat(filename).mtime
      record_changed = true
      file_record.file_created_on = File.stat(filename).atime
      file_record.file_updated_on = File.stat(filename).mtime
      file_record.save or raise IOError.new("Unable to cache path #{filename} because #{file_record.errors}")
    end
  end
  
  def MediaPathDao.cached?(filename)
    file_record = Euterpe::Dashboard::MediaPath.find_by_path(filename)
    
    file_record && file_record.file_updated_on.to_s == File.stat(filename).mtime.to_s
  end
  
  def MediaPathDao.pending_non_mp3_count
    Euterpe::Dashboard::MediaPath.pending_non_mp3_count
  end
  
  def MediaPathDao.purge_cached_path(path)
    path_record = Euterpe::Dashboard::MediaPath.find_by_path(path)
    path_record.destroy or raise IOError.new("Unable to purge path record because #{path_record.errors}")
  end
end

class TrackDao
  def TrackDao.save_to_db(track, disc_record = nil)
    preexisting_path = find_preexisting(track)
    track_record = track_with_path(preexisting_path, track)
    
    load_from_model(track_record, disc_record, track)
    track_record.save
  end
  
  def TrackDao.cache_track(track, disc_record = nil)
    preexisting_path = find_preexisting(track)
    track_record = track_with_path(preexisting_path, track)
    
    if !preexisting_path ||
        track_record.file_changed?
      
      load_from_model(track_record, disc_record, track)
      track_record.save or raise IOError.new("Unable to cache track with path #{track_record.media_path}")
      
      track_record
    else
      []
    end
  end
  
  def TrackDao.load_track_from_record(track_record, disc = nil)
    load_from_record(track_record, disc)
  end
  
  def TrackDao.file_changed?(path)
    path = Euterpe::Dashboard::MediaPath.find_by_path(path)
    if path
      if path.changed?
        true
      else
        false
      end
    else
      true
    end
  end
  
  def TrackDao.pending_count
    Euterpe::Dashboard::Track.pending_count
  end
  
  private
  
  def self.find_preexisting(track)
    Euterpe::Dashboard::MediaPath.find_by_path(track.path)
  end
  
  def self.track_with_path(path, model_track)
    unless path
      track_record = Euterpe::Dashboard::Track.new
      track_record.media_path = Euterpe::Dashboard::MediaPath.new
      track_record.media_path.path = model_track.path
      track_record.media_path.file_created_on = File.stat(model_track.path).atime
      track_record.media_path.file_updated_on = File.stat(model_track.path).mtime
    else
      track_record = Euterpe::Dashboard::Track.find_by_media_path_id(path.id)
      raise IOError.new("Unable to locate track record for preexisting path") unless track_record
    end
    
    track_record
  end
  
  def self.load_from_record(track_record, disc)
    track = Track.new(track_record.media_path.path)
    track.disc = disc
    track.name = track_record.name if track_record.name && '' != track_record.name
    track.artist_name = track_record.artist_name if track_record.artist_name && '' != track_record.artist_name
    track.sequence = track_record.sequence if track_record.sequence && '' != track_record.sequence
    track.genre = track_record.genre.name if track_record.genre && '' != track_record.genre.name
    track.comment = track_record.comment if track_record.comment && '' != track_record.comment
    track.encoder = track_record.encoder.split(' / ') if track_record.encoder && '' != track_record.encoder
    track.remix = track_record.remix if track_record.remix && '' != track_record.remix
    track.release_date = track_record.release_date if track_record.release_date && '' != track_record.release_date
    track.unique_id = track_record.unique_id  if track_record.unique_id && '' != track_record.unique_id
    track.musicbrainz_artist_id = track_record.musicbrainz_artist_id if track_record.musicbrainz_artist_id && '' != track_record.musicbrainz_artist_id
    track.sort_order = track_record.sort_order if track_record.sort_order && '' != track_record.sort_order
    track.artist_sort_order = track_record.artist_sort_order if track_record.artist_sort_order && '' != track_record.artist_sort_order
    # TODO: track_record.image = track.image
    
    track_record.artists.each do |artist_record|
      track.featured_artists << artist_record.name
    end
    
    track
  end
  
  def self.load_from_model(track_record, disc_record, track)
    track_record.disc = disc_record
    track_record.name = track.name || ''
    track_record.artist_name = track.artist_name || ''
    track_record.sequence = track.sequence || ''
    track_record.genre = GenreDao.find_genre(track)
    track_record.comment = track.comment || ''
    track_record.encoder = track.encoder ? track.encoder.join(' / ') : ''
    track_record.remix = track.remix || ''
    track_record.release_date = track.release_date || ''
    track_record.unique_id = track.unique_id || ''
    track_record.musicbrainz_artist_id = track.musicbrainz_artist_id || ''
    track_record.sort_order = track.sort_order || ''
    track_record.artist_sort_order = track.artist_sort_order || ''
    # TODO: track_record.image = track.image
    
    track.featured_artists.each do |artist_name|
      artist_record = Euterpe::Dashboard::Artist.find_by_name(artist_name)
      unless artist_record
        artist_record = Euterpe::Dashboard::Artist.new
        artist_record.name = artist_name
      end
      track_record.artists << artist_record
    end
  end
end

class DiscDao
  def DiscDao.save_to_db(disc, album_record = nil)
    disc_record = load_from_model(disc, album_record)
    disc.tracks.each do |track|
      TrackDao.save_to_db(track, disc_record)
    end
    
    disc_record.save
  end
  
  def DiscDao.cache_disc(disc, album_record = nil)
    updated_tracks = []
    
    disc_record = load_from_model(disc, album_record)
    disc.tracks.each do |track|
      updated_tracks += [TrackDao.cache_track(track, disc_record)]
    end

    updated_tracks
  end
  
  def DiscDao.load_disc_from_record(disc_record, album = nil)
    disc = load_from_record(disc_record, album)
    disc_record.tracks.each do |track_record|
      disc.tracks << TrackDao.load_track_from_record(track_record, disc)
    end
    
    disc
  end

  def DiscDao.find_changed_paths(paths)
    changed_paths = []
    directories = []
    
    paths.each do |path|
      directories << File.dirname(path)
    end
    
    directories = directories.compact.uniq
    
    directories.each do |directory|
      next unless Euterpe::Dashboard::DiscBucket.changed?(directory)
      
      Dir.glob(File.join(directory, '*.mp3')).each do |path|
        changed_paths << path if TrackDao.file_changed?(path)
      end
    end 
    
    changed_paths
  end
  
  private
  
  def self.load_from_record(disc_record, album = nil)
    disc = Disc.new
    disc.album = album

    disc.number = disc_record.number if disc_record.number && '' != disc_record.number
    disc.number_of_tracks = disc_record.number_of_tracks if disc_record.number_of_tracks && '' != disc_record.number_of_tracks
    
    disc
  end
  
  def self.load_from_model(disc, album_record = nil)
    disc_record = Euterpe::Dashboard::Disc.new
    disc_record.album = album_record

    disc_record.number = disc.number
    disc_record.number_of_tracks = disc.number_of_tracks
    
    disc_record
  end
end

class AlbumDao
  def AlbumDao.find_generously(search_term)
    found_albums = []
    found_album_records = Euterpe::Dashboard::Album.find_generously(search_term)
    
    found_album_records.each do |album_record|
      found_albums << load_album_from_record(album_record)
    end
    
    found_albums
  end
  
  def AlbumDao.choose_randomly
    random_album_record = Euterpe::Dashboard::Album.find_random
    load_album_from_record(random_album_record) if random_album_record
  end
  
  def AlbumDao.choose_most_recent
    recent_album_record = Euterpe::Dashboard::Album.find_most_recently_modified
    load_album_from_record(recent_album_record) if recent_album_record
  end
  
  def AlbumDao.save_to_db(album)
    album_record = load_from_model(album)
    album.discs.compact.each do |disc|
      DiscDao.save_to_db(disc, album_record)
    end
    
    album_record.save
  end
  
  def AlbumDao.cache_album(album)
    updated_tracks = []
    
    album_record = load_from_model(album)
    album.discs.compact.each do |disc|
      updated_tracks += DiscDao.cache_disc(disc, album_record)
    end
    
    album.non_media_files.each do |path|
      MediaPathDao.cache_file(path)
    end
    
    updated_tracks
  end
  
  def AlbumDao.load_album_from_record(album_record)
    album = load_from_record(album_record)
    album.cached_album = album_record
    
    album_record.discs.each do |disc_record|
      album.discs[disc_record.number] = DiscDao.load_disc_from_record(disc_record, album)
    end
    
    album
  end
  
  def AlbumDao.merge_cached_albums(master, subject)
    # TODO: jeez, less cheesy please!
    target_disc = master.discs.first

    subject.discs.each do |disc|
      disc.tracks.each do |track|
        target_disc.tracks << track
      end
    end
    subject.destroy
    
    load_album_from_record(master)
  end
  
  def AlbumDao.pending_count
    Euterpe::Dashboard::Album.pending_count
  end
  
  def AlbumDao.all_pending
    Euterpe::Dashboard::Album.find(:all, :order => 'id DESC')
  end
  
  def AlbumDao.purge_cached_album(album)
    media_paths = album.discs.compact.collect{|disc| disc.tracks.collect{|track| track.media_path}}

    album.destroy

    media_paths.flatten.each do |media_path|
      media_path.destroy
    end
  end
  
  private
  
  def self.load_from_record(album_record)
    album = Album.new
    
    if album_record.name && '' != album_record.name
      album.name = album_record.name
    end

    if album_record.subtitle && '' != album_record.subtitle
      album.subtitle = album_record.subtitle
    end

    if album_record.version_name && '' != album_record.version_name
      album.version_name = album_record.version_name
    end

    if album_record.artist_name && '' != album_record.artist_name
      album.artist_name = album_record.artist_name
    end
    
    if album_record.number_of_discs && '' != album_record.number_of_discs
      album.number_of_discs = album_record.number_of_discs
    end
    
    if album_record.genre && '' != album_record.genre.name 
      album.genre = album_record.genre.name
    end
    
    album.release_date = album_record.release_date if album_record.release_date && '' != album_record.release_date
    album.compilation = album_record.compilation if album_record.compilation && '' != album_record.compilation
    album.mixer = album_record.mixer if album_record.mixer && '' != album_record.mixer
    album.musicbrainz_album_id = album_record.musicbrainz_album_id if album_record.musicbrainz_album_id && '' != album_record.musicbrainz_album_id
    album.musicbrainz_album_artist_id = album_record.musicbrainz_album_artist_id if album_record.musicbrainz_album_artist_id && '' != album_record.musicbrainz_album_artist_id
    album.musicbrainz_album_type = album_record.musicbrainz_album_type if album_record.musicbrainz_album_type && '' != album_record.name
    album.musicbrainz_album_status = album_record.musicbrainz_album_status if album_record.musicbrainz_album_status && '' != album_record.musicbrainz_album_status
    album.musicbrainz_album_release_country = album_record.musicbrainz_album_release_country if album_record.musicbrainz_album_release_country && '' != album_record.musicbrainz_album_release_country
    album.sort_order = album_record.sort_order if album_record.sort_order && '' != album_record.sort_order
    
    album
  end
  
  def self.load_from_model(album)
    album_record = Euterpe::Dashboard::Album.new
    
    album_record.name = album.name || ''
    album_record.subtitle = album.subtitle || ''
    album_record.version_name = album.version_name || ''
    album_record.artist_name = album.artist_name || ''
    album_record.number_of_discs = album.number_of_discs || 0
    album_record.genre = GenreDao.find_genre(album)
    album_record.release_date = album.release_date || ''
    album_record.compilation = album.compilation || ''
    album_record.mixer = album.mixer || ''
    album_record.musicbrainz_album_id = album.musicbrainz_album_id || ''
    album_record.musicbrainz_album_artist_id = album.musicbrainz_album_artist_id || ''
    album_record.musicbrainz_album_type = album.musicbrainz_album_type || ''
    album_record.musicbrainz_album_status = album.musicbrainz_album_status || ''
    album_record.musicbrainz_album_release_country = album.musicbrainz_album_release_country || ''
    album_record.sort_order = album.sort_order || ''
    
    album_record
  end
end
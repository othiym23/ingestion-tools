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
  
  def self.load_from_model(disc, album_record = nil)
    disc_record = Euterpe::Dashboard::Disc.new
    disc_record.album = album_record

    disc_record.number = disc.number
    disc_record.number_of_tracks = disc.number_of_tracks
    
    disc_record
  end
end

class AlbumDao
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
    
    updated_tracks
  end
  
  def AlbumDao.find_generously(search_term)
    found_albums = []
    found_album_records = Euterpe::Dashboard::Album.find_generously(search_term)
    
    found_album_records.each do |album|
      paths = album.discs.collect{|disc| disc.tracks.collect{|track| track.media_path.path}}.flatten
      found_albums += AlbumDao.load_albums_from_paths(paths)
    end
    
    found_albums
  end
  
  private
  
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
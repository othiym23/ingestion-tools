$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'album'
require 'disc'
require 'dao/track_dao'

class AlbumDao
  def AlbumDao.load_albums_from_paths(paths)
    albums = {}

    paths.each do |path|
      track_dao = TrackDao.new(path)
      track = track_dao.load_track(path)

      album_name = track_dao.album_name
      if albums[album_name].nil?
        new_album = Album.new
        new_album.name = album_name
        albums[album_name] = new_album
      end
      album = albums[album_name]
      
      disc_number = track_dao.disc_number
      if album.discs[disc_number].nil?
        new_disc = Disc.new
        new_disc.number = disc_number
        album.discs[disc_number] = new_disc
        new_disc.album = album
      end
      disc = album.discs[disc_number]
      track.disc = disc

      disc.tracks << track
    end

    albums.each do |album_name,album|
      artists = []
      genres = []
      years = []
      
      album.set_mixer!
      album.set_encoder_from_comments!
      
      album.discs.compact.each do |disc|
        disc.tracks.each do |track|
          artists << track.artist_name
          genres << track.genre
          years << track.release_date
        end
      end
      
      if 1 == artists.compact.uniq.size
        album.artist_name = artists.first
        album.compilation = false
      else
        album.artist_name = "Various Artists"
        album.compilation = true
      end
      
      if 1 == genres.compact.uniq.size
        album.genre = genres.first
      else
        album.genre = genres.compact.uniq.join(", ")
      end
      
      if 1 == years.compact.uniq.size
        album.release_date = years.compact.first
      else
        album.release_date = years.compact.uniq.join(", ")
      end
    end
    
    albums.values
  end
end
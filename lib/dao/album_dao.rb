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
        new_album.number_of_discs = track_dao.number_of_discs_in_set
        albums[album_name] = new_album
      end
      album = albums[album_name]
      album.musicbrainz_album_artist_id = track_dao.musicbrainz_album_artist_id if track_dao.musicbrainz_album_artist_id
      album.musicbrainz_album_id = track_dao.musicbrainz_album_id if track_dao.musicbrainz_album_id
      album.musicbrainz_album_type = track_dao.musicbrainz_album_type if track_dao.musicbrainz_album_type
      album.musicbrainz_album_status = track_dao.musicbrainz_album_status if track_dao.musicbrainz_album_status
      album.musicbrainz_album_release_country = track_dao.musicbrainz_album_release_country if track_dao.musicbrainz_album_release_country
      
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
      
      album.set_mixer!
      album.set_encoder_from_comments!
      album.find_hidden_soundtrack!
      
      album.discs.compact.each do |disc|
        disc.tracks.each do |track|
          artists << track.artist_name
          genres << track.genre
          years << track.release_date
          musicbrainz_artist_ids << track.musicbrainz_artist_id
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
        album.release_date = years.compact.uniq.sort.last
      end
      
      if 1 == musicbrainz_artist_ids.compact.uniq.size &&
        (album.musicbrainz_album_artist_id.nil? ||
         '' == album.musicbrainz_album_artist_id)
        album.musicbrainz_album_artist_id = musicbrainz_artist_ids.compact.uniq.first
      end
    end
    
    albums.values
  end
end
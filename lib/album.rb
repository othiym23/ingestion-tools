$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '.')))

require 'disc'
require 'track'

class Album
  attr_accessor :name, :artist_name, :discs
  attr_accessor :number_of_discs, :number_of_tracks, :release_date, :compilation
  attr_accessor :genre, :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  
  def initialize
    @discs = []
  end
  
  def Album.from_paths(paths)
    albums = {}

    paths.each do |path|
      track = Track.new(path)

      album_name = track.album_name
      if albums[album_name].nil?
        new_album = Album.new
        new_album.name = track.album_name
        albums[album_name] = new_album
      end
      album = albums[album_name]
      
      disc_number = track.disc_number
      if album.discs[disc_number].nil?
        new_disc = Disc.new
        new_disc.number = track.disc_number
        album.discs[disc_number] = new_disc
      end
      disc = album.discs[disc_number]

      disc.tracks << track

      albums[album_name].number_of_discs = albums[album_name].discs.nitems
    end

    albums.each do |album_name,album|
      artists = []
      genres = []

      album.discs.compact.each do |disc|
        disc.tracks.each do |track|
          artists << track.artist_name
          genres << track.genre
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
    end
    
    albums.values
  end
  
  def number_of_tracks
    @number_of_tracks = @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks }
  end
end
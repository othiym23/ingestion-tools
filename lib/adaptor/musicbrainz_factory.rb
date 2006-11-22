require 'musicbrainz_lite'

class MusicBrainz::MatcherDao
  def self.find_album_matches(ingestion_album)
    # HEURISTIC: try to find the albums by exact matches first...
    albums = MusicBrainz::Album.search(ingestion_album.artist_name, ingestion_album.name, true)

    # TODO: fix the following to work for multiple disc albums
    candidates = albums.select {|album| album.tracks.size == ingestion_album.tracks.size}

    # HEURISTIC: ...then loosen the search if there aren't any results
    unless candidates.size > 0
      albums = MusicBrainz::Album.search(ingestion_album.artist_name, ingestion_album.name, false) unless candidates.size > 0

      # TODO: fix the following to work for multiple disc albums
      candidates = albums.select {|album| album.tracks.size == ingestion_album.tracks.size}
    end
    
    candidates
  end
  
  def self.populate_album_from_match(ingestion_album, musicbrainz_album)
    ingestion_album.musicbrainz_album_id = musicbrainz_album.id
    ingestion_album.musicbrainz_album_name = musicbrainz_album.name
    ingestion_album.musicbrainz_album_status = musicbrainz_album.status
    ingestion_album.musicbrainz_album_type = musicbrainz_album.type
    ingestion_album.musicbrainz_album_release_country = musicbrainz_album.release_dates.first['country'] if musicbrainz_album.release_dates
    ingestion_album.musicbrainz_album_artist_id = musicbrainz_album.artist.id
    ingestion_album.musicbrainz_album_artist_type = musicbrainz_album.artist.type
    ingestion_album.musicbrainz_album_artist_name = musicbrainz_album.artist.name
    ingestion_album.musicbrainz_album_artist_sort_order = musicbrainz_album.artist.sort_name
    
    musicbrainz_tracks = musicbrainz_album.tracks
    
    ingestion_album.tracks.each_with_index do |track,index|
      musicbrainz_track = musicbrainz_tracks[index]

      track.unique_id = musicbrainz_track.id
      track.musicbrainz_name = musicbrainz_track.name
      track.musicbrainz_duration = musicbrainz_track.duration
      track.musicbrainz_artist_id = musicbrainz_track.artist.id
      track.musicbrainz_artist_name = musicbrainz_track.artist.name
      track.musicbrainz_artist_type = musicbrainz_track.artist.type
      track.musicbrainz_artist_sort_order = musicbrainz_track.artist.sort_name
    end
  end
end
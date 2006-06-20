$: << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))
$: << File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'test_helper'
require 'ingestion_case'

require 'adaptor/euterpe_dashboard_factory'
require 'app/models/media_path'
require 'app/models/disc_bucket'

class EuterpeDashTest < IngestionCase
  def setup
    Euterpe::Dashboard::Track.delete_all
    Euterpe::Dashboard::Disc.delete_all
    Euterpe::Dashboard::Album.delete_all
    Euterpe::Dashboard::Artist.delete_all
    Euterpe::Dashboard::Genre.delete_all
    Euterpe::Dashboard::MediaPath.delete_all
    Euterpe::Dashboard::DiscBucket.delete_all
  end
  
  def test_save_album_metadata_to_db
    albums = load_albums("Razor X Productions/*/*.mp3")
    
    assert AlbumDao.save_to_db(albums.first)
  end

  def test_cache_album_metadata_to_db
    albums = load_albums("Razor X Productions/*/*.mp3")
    
    processed_tracks = AlbumDao.cache_album(albums.first)
    assert_equal 20, processed_tracks.size
    processed_tracks.each do |track_record|
      assert_equal 'Razor X Productions', track_record.artist_name
      assert_equal 'Killing Sound', track_record.disc.album.name
    end
  end
  
  def test_disc_buckets
    album_paths = find_files("Razor X Productions/*/*.mp3")
    
    updated_paths = DiscDao.find_changed_paths(album_paths)
    assert_equal 20, updated_paths.size

    unchanged_paths = DiscDao.find_changed_paths(album_paths)
    assert_equal 0, unchanged_paths.size
  end
end

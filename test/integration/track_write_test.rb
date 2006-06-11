$: << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))

require 'fileutils'

require 'test/unit'
require 'path_utils'
require 'dao/track_dao'

class TrackWriteTest < Test::Unit::TestCase
  def setup
    @source_root = File.expand_path(File.join(File.dirname(__FILE__), 'sample_files'))
    @staging_root = File.expand_path(File.join(File.dirname(__FILE__), 'staging'))
    @processed_root = File.expand_path(File.join(File.dirname(__FILE__), 'processed'))
  end
  
  def test_integrated_write_track
    trackfile = 'Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 01 - Killer (feat. He-Man).mp3'
    source_file = File.join(@source_root, trackfile) 
    staging_file = File.join(@staging_root, trackfile)
    processed_file =
      File.join(@processed_root,
                'Razor X Productions/Killing Sound/Razor X Productions - Killing Sound - 01 - Killer feat HeMan.mp3')
    
    begin
      assert PathUtils.safe_copy(source_file, staging_file)
    
      track_dao = TrackDao.new(staging_file)
    
      assert TrackDao.archive_mp3_from_track_dao(@processed_root, track_dao)
      assert File.exists?(processed_file),
             "'#{processed_file}' should exist as a canonicalized location."
      
      processed_track_dao = TrackDao.new(processed_file)
      
      assert_equal track_dao.track.artist_name, processed_track_dao.track.artist_name,
                   "artist names should match"
      assert_equal track_dao.track.comment, processed_track_dao.track.comment,
                   "comments should match"
      assert_equal track_dao.track.encoder, processed_track_dao.track.encoder,
                   "encoder arrays should match"
      assert_equal track_dao.track.featured_artists, processed_track_dao.track.featured_artists,
                   "featured artists should match"
      assert_equal track_dao.track.genre, processed_track_dao.track.genre,
                   "genres should match"
      assert_equal track_dao.track.name, processed_track_dao.track.name,
                   "track names should match"
      assert_equal track_dao.track.release_date, processed_track_dao.track.release_date,
                   "release dates should match"
      assert_equal track_dao.track.sequence, processed_track_dao.track.sequence,
                   "track numbers should match"
    ensure
      clean_paths
    end
  end
  
  private
  
  def clean_paths
    FileUtils.rmtree([@staging_root, @processed_root])
  end
end

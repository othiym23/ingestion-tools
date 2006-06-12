$: << File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require 'fileutils'
require 'test/unit'

require 'path_utils'
require 'dao/track_dao'

class IngestionCase < Test::Unit::TestCase

  def test_stub
  end
  
  protected

  def load_track(path)
    track_path = File.join(File.expand_path('../../mp3info/sample-metadata'), path)
    TrackDao.new(track_path).track
  end
  
  def load_staged_track(path)
    TrackDao.new(path).track
  end
  
  def load_albums(path)
    album_paths = find_files(path)
    AlbumDao.load_albums_from_paths(album_paths)
  end

  def find_files(path)
    Dir.glob(File.join(File.expand_path('../../mp3info/sample-metadata'), path))
  end
  
  def stage_mp3(relative_path, staging_dir = 'staging')
    source_file = File.join(File.expand_path('../../mp3info/sample-metadata/'),
                            relative_path)
    staging_file = File.join(staging_dir, relative_path)

    begin
      FileUtils.mkdir(staging_dir)
      PathUtils.safe_copy(source_file, staging_file)
      
      yield(staging_file)
    ensure
      FileUtils.rmtree(staging_dir)
    end
  end
end

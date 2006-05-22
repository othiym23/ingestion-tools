require 'test/unit'

require '../lib/track'

class TrackTest < Test::Unit::TestCase
  def test_basic_track_instantiation_from_path
    track = Track.from_file './zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'
    assert_equal 'zovietfrance', track.path_metadata.artist_name
    assert_equal 'zovietfrance', track.filename_metadata.artist_name
  end
end

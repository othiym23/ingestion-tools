require 'test/unit'

require '../lib/track'

class TrackTest < Test::Unit::TestCase
  def test_basic_track_instantiation_from_path
    track = Track.new '../../mp3info/sample-metadata/zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'
    assert_equal ':zoviet*france:', track.artist_name
    assert_equal 'Popular Soviet Songs And Youth Music', track.album_name
  end
end

require 'test/unit'

require '../lib/track'

class TrackTest < Test::Unit::TestCase
  def test_basic_track_instantiation_from_path
    track = Track.new '../../mp3info/sample-metadata/zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'
    assert_equal ':zoviet*france:', track.artist_name
    assert_equal 'Popular Soviet Songs And Youth Music', track.album_name
    assert_equal 'Experimental', track.genre
    assert_equal 7, track.sequence
    assert_equal 9, track.max_sequence
    assert_equal 3, track.disc_number
    assert_equal 3, track.max_disc_number
    assert_equal '(ID3v1 Comment) [XXX]: RIPT with GRIP', track.comment
  end
end

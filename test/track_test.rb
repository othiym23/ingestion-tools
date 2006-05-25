$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))

require 'test/unit'
require 'dao/track_dao'

class TrackTest < Test::Unit::TestCase
  def test_basic_track_instantiation_from_path
    path = '../../mp3info/sample-metadata/zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'
    track = TrackDao.new(path).load_track(path)
    assert_equal ':zoviet*france:', track.artist_name
    assert_equal 'Popular Soviet Songs And Youth Music', track.album_name
    assert_equal 'Experimental', track.genre
    assert_equal 7, track.sequence
    assert_equal '(ID3v1 Comment) [XXX]: RIPT with GRIP', track.comment
  end
end

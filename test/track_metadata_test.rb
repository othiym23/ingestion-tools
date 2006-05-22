require 'test/unit'

require '../lib/track_metadata'

class TrackMetadataTest < Test::Unit::TestCase
  def test_find_path_artist
    assert_equal 'Eminem',
                 TrackPathMetadata.new('./Eminem/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.aac').artist_name
  end

  def test_disc_number_multi_disc
    path_data = TrackPathMetadata.new './zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'
    assert_equal 'Popular Soviet Songs And Youth Music', path_data.album_name
    assert_equal 3, path_data.disc_number
  end
end

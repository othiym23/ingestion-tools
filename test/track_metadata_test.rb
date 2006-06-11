$: << File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require 'test/unit'
require 'album'
require 'disc'
require 'track'
require 'track_metadata'

class TrackMetadataTest < Test::Unit::TestCase
  def test_find_path_artist
    assert_equal 'Eminem',
                 TrackPathMetadata.load_from_path('./Eminem/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.aac').album_artist_name
  end

  def test_disc_number_multi_disc
    path_data = TrackPathMetadata.load_from_path('./zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3')
    assert_equal 'Popular Soviet Songs And Youth Music', path_data.album_name
    assert_equal 3, path_data.disc_number
  end
  
  def test_disk_number_in_canonical_path
    path = TrackPathMetadata.new
    path.album_artist_name = "Razor X Productions"
    path.album_name = "Killing Sound"
    path.disc_number = 1
    
    assert_equal 'Razor X Productions', path.artist_directory
    assert_equal 'Killing Sound disc 1', path.disc_directory
    assert_equal 'Razor X Productions' << File::SEPARATOR << 'Killing Sound disc 1', path.canonical_path
  end
  
  def test_diacritic_in_canonical_path
    path = TrackPathMetadata.new
    path.album_artist_name = "Björk"
    path.album_name = "Médulla Piñata"
    
    assert_equal 'Bjork', path.artist_directory
    assert_equal 'Medulla Pinata', path.disc_directory
    assert_equal 'Bjork' << File::SEPARATOR << 'Medulla Pinata', path.canonical_path
  end
  
  def test_diacritic_in_canonical_filename
    filename = TrackFilenameMetadata.new
    filename.artist_name = "Björk"
    filename.album_name = "Médulla Piñata"
    filename.track_name = "Jøga"
    filename.sequence = 1
    
    assert_equal 'Bjork - Medulla Pinata - 01 - Joga.mp3', filename.canonical_filename
  end
  
  def test_diacritic_in_canonical_full_path
    id3 = TrackId3Metadata.new
    id3.album_artist_name = "Björk"
    id3.artist_name = "Björk"
    id3.album_name = "Médulla Piñata"
    id3.track_name = "Jøga"
    id3.sequence = 1
    
    assert_equal 'Bjork' << File::SEPARATOR << 'Medulla Pinata' << File::SEPARATOR << 'Bjork - Medulla Pinata - 01 - Joga.mp3',
                 id3.canonical_full_path
  end
  
  def test_diacritic_in_canonical_full_path_from_track
    track = Track.new("ignored")
    track.disc = Disc.new
    track.disc.album = Album.new
    
    track.artist_name = "Björk"
    track.disc.album.name = "Médulla Piñata"
    track.sequence = 4
    track.name = "Jøga"
        
    assert_equal 'Bjork' << File::SEPARATOR << 'Medulla Pinata' << File::SEPARATOR << 'Bjork - Medulla Pinata - 04 - Joga.mp3',
                 TrackId3Metadata.load_from_track(track).canonical_full_path
  end
  
  def test_diacritic_in_canonical_filename_from_track
    track = Track.new("ignored")
    track.disc = Disc.new
    track.disc.album = Album.new
    
    track.artist_name = "Björk"
    track.disc.album.name = "Médulla Piñata"
    track.sequence = 4
    track.name = "Jøga"
        
    assert_equal 'Bjork - Medulla Pinata - 04 - Joga.mp3',
                 TrackFilenameMetadata.load_from_track(track).canonical_filename
  end
end

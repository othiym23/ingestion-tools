$: << File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require 'fileutils'

require 'ingestion_case'
require 'album'
require 'disc'
require 'track'
require 'track_metadata'
require 'path_utils'

class TrackMetadataTest < IngestionCase
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
    assert_equal File.join('Razor X Productions', 'Killing Sound disc 1'), path.canonical_path
  end
  
  def test_diacritic_in_canonical_path
    path = TrackPathMetadata.new
    path.album_artist_name = "Björk"
    path.album_name = "Médulla Piñata"
    
    assert_equal 'Bjork', path.artist_directory
    assert_equal 'Medulla Pinata', path.disc_directory
    assert_equal File.join('Bjork', 'Medulla Pinata'), path.canonical_path
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
    
    assert_equal File.join('Bjork', 'Medulla Pinata', 'Bjork - Medulla Pinata - 01 - Joga.mp3'),
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
        
    assert_equal File.join('Bjork', 'Medulla Pinata', 'Bjork - Medulla Pinata - 04 - Joga.mp3'),
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
  
  def test_id3_remixer
    stage_mp3('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3') do |file|
      id3 = TrackId3Metadata.load_from_path(file) 
      id3.remixer = 'The Bug'
      
      id3.save
      
      saved_id3 = TrackId3Metadata.load_from_path(file)
      
      assert_equal 'The Bug', saved_id3.remixer,
                   "remixer should survive being saved"
    end
  end
  
  def test_id3_remix_name
    stage_mp3('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3') do |file|
      id3 = TrackId3Metadata.load_from_path(file) 
      id3.remix_name = 'original version'
      
      id3.save
      
      saved_id3 = TrackId3Metadata.load_from_path(file)
      
      assert_equal 'original version', saved_id3.remix_name, "remix name should survive being saved"
    end
  end
  
  def test_id3_featured_artists
    stage_mp3('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3') do |file|
      id3 = TrackId3Metadata.load_from_path(file)
      assert_equal 2, id3.featured_artists.size
      assert_equal ['Cutty Ranks', 'The Bug'], id3.featured_artists,
                   "featured artists should be found on load"
      id3.featured_artists = []
      id3.featured_artists << 'Shabba Ranks'
      id3.featured_artists << 'Daddy Freddy'
      
      id3.save
      
      saved_id3 = TrackId3Metadata.load_from_path(file)
      assert_equal ['Shabba Ranks', 'Daddy Freddy'], saved_id3.featured_artists,
                   "featured artists should survive being saved"
    end
  end
  
  def test_id3_attached_picture
    stage_mp3('RAC/Double Jointed/03 - RAC - Nine.mp3') do |file|
      id3 = TrackId3Metadata.load_from_path(file)

      assert id3.album_image,
             "this file definitely had an image in it at one time"
      assert_equal 'image/jpg', id3.album_image.mime_type
      assert_equal 'Cover (front)', id3.album_image.picture_type_name
      assert_equal 5013, id3.album_image.value.length
      
      id3.album_image.picture_type_name = 'Other'
      id3.album_image.mime_type = 'image/png'
      
      id3.save
      
      saved_id3 = TrackId3Metadata.load_from_path(file)

      assert saved_id3.album_image,
             "this file definitely had an image in it at one time"
      assert_equal 'image/png', saved_id3.album_image.mime_type
      assert_equal 'Other', saved_id3.album_image.picture_type_name
      assert_equal 5013, saved_id3.album_image.value.length
      
      cover_image = saved_id3.album_image
      cover_image.picture_type_name = 'Cover (front)'
      cover_image.mime_type = 'image/jpg'
      saved_id3.album_image = nil
      
      saved_id3.save
      
      reheated_id3 = TrackId3Metadata.load_from_path(file)
      
      assert_equal nil, reheated_id3.album_image
      reheated_id3.album_image = cover_image
      
      reheated_id3.save
      
      rehashed_id3 = TrackId3Metadata.load_from_path(file)

      assert rehashed_id3.album_image,
             "this file definitely had an image in it at one time"
      assert_equal 'image/jpg', rehashed_id3.album_image.mime_type
      assert_equal 'Cover (front)', rehashed_id3.album_image.picture_type_name
      assert_equal 5013, rehashed_id3.album_image.value.length
    end
  end
end

$: << File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))

require 'ingestion_case'
require 'dao/track_dao'

class TrackTest < IngestionCase
  def test_basic_track_instantiation_from_path
    track = load_track('zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3')

    assert_equal ':zoviet*france:', track.artist_name
    assert_equal 'Experimental', track.genre
    assert_equal 7, track.sequence
    assert_equal 'RIPT with GRIP', track.comment
  end
  
  def test_featured_artist_parsing
    track = load_track('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3')

    assert_equal 2, track.featured_artists.size, "Load process should have found 2 featured artists."
    assert_equal ['Cutty Ranks', 'The Bug'], track.featured_artists
    assert_equal 'Boom Boom Claat', track.name, "featured artists should be removed from track name {#{track.name}}"
  end
  
  def test_featured_artist_editing
    stage_mp3('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3') do |file|
      track = load_staged_track(file)
      assert_equal 2, track.featured_artists.size,
                   "Load process should have found 2 featured artists."
      assert_equal 'Boom Boom Claat', track.name,
                   "featured artists should be removed from track name {#{track.name}}"
      track.featured_artists = ["Daddy Freddy", "Buju Banton", "Zulu Warrior"]
      TrackDao.save(track)
      
      saved_track = load_staged_track(file)
      assert_equal 3, track.featured_artists.size
      assert_equal ["Daddy Freddy", "Buju Banton", "Zulu Warrior"],
                   saved_track.featured_artists
      assert_equal 'Boom Boom Claat', saved_track.name,
                   "featured artists should be removed from track name {#{track.name}}"
      saved_track.featured_artists << "Yellowman"
      saved_track.featured_artists << "The Bug"
      TrackDao.save(saved_track)
      
      reheated_track = load_staged_track(file)
      assert_equal 5, reheated_track.featured_artists.size
      assert_equal ["Daddy Freddy", "Buju Banton", "Zulu Warrior", "Yellowman", "The Bug"],
                   reheated_track.featured_artists
      assert_equal 'Boom Boom Claat', reheated_track.name,
                   "featured artists should be removed from track name {#{track.name}}"
    end
  end
  
  def test_image_loading
    track = load_track('RAC/Double Jointed/03 - RAC - Nine.mp3')

    assert track.image,
           "this track definitely had an image associated with it at one time"
    assert_equal 'image/jpg', track.image.mime_type
    assert_equal 'Cover (front)', track.image.picture_type_name
    assert_equal 5013, track.image.value.length
  end
  
  def test_image_transferral
    stage_mp3('RAC/Double Jointed/03 - RAC - Nine.mp3') do |original|
      source = load_staged_track(original)
      
      stage_mp3('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3',
                'staging2') do |target|
        destination = load_staged_track(target)
        destination.image = source.image
        
        assert destination.image,
               "this track definitely had an image associated with it at one time"
        assert_equal 'image/jpg', destination.image.mime_type
        assert_equal 'Cover (front)', destination.image.picture_type_name
        assert_equal 5013, destination.image.value.length
        assert_equal source.image, destination.image

        TrackDao.save(destination)

        saved_track = load_staged_track(target)

        assert saved_track.image,
               "this track definitely had an image associated with it at one time"
        assert_equal 'image/jpg', saved_track.image.mime_type
        assert_equal 'Cover (front)', saved_track.image.picture_type_name
        assert_equal 5013, saved_track.image.value.length
        
        assert_equal destination.image, saved_track.image
      end
    end
  end
  
  def test_standard_remix_parsing
    track = load_track('Aphex Twin/Ventolin/Aphex Twin - Ventolin - 01 - Ventolin Salbutamol Mix.mp3')

    assert_equal 'Ventolin', track.name
    assert_equal 'Salbutamol mix', track.remix, "'Salbutamol mix' should be removed from track name {#{track.name}}"
  end
  
  def test_nonstandard_remix_parsing
    track = load_track('Aphex Twin/Richard D James Album/Aphex Twin - Richard D James Album - 13 - GirlBoy Song 18 Snarerush Mix.mp3')

    assert_equal 'Girl/Boy Song', track.name
    assert_equal '£18 Snarerush mix', track.remix, "'£18 Snarerush mix' should be removed from track name {#{track.name}}"
    
    track = load_track('Various Artists/Wonka Beats/Aquastep - Wonka Beats - 01 - Oempa Loempa (original).mp3')

    assert_equal 'Oempa Loempa', track.name
    assert_equal 'original', track.remix
    
    track = load_track('Various Artists/Wonka Beats/Aquastep - Wonka Beats - 08 - Oempa Loempa (instrumental).mp3')

    assert_equal 'Oempa Loempa', track.name
    assert_equal 'instrumental', track.remix
    
    track = load_track('Various Artists/Wonka Beats/Aquastep - Wonka Beats - 16 - Oempa Loempa (vocal).mp3')

    assert_equal 'Oempa Loempa', track.name
    assert_equal 'vocal', track.remix
  end
  
  def test_track_release_date
    track = load_track('324/Boutokunotaiyo/324 - Boutokunotaiyo - 05 - Japanese Characters.mp3')

    assert_equal '2002', track.release_date
  end
  
  def test_track_musicbrainz_metadata
    track = load_track('324/Boutokunotaiyo/324 - Boutokunotaiyo - 03 - Red Origin Still Streaming.mp3')

    assert_equal '7e5f38c8-eff6-4204-9f84-e344c54e7ca8', track.musicbrainz_artist_id
    assert_equal '5cde5a57-6118-4d67-946e-4e565e2c7b54', track.unique_id
  end
  
  def test_wack_grip_id3_tag
    track = load_track('Master Fool/Skilligans Island/Master Fool - Skilligan\'s Island - 14 - I Still Live With My Moms.mp3')
    
    assert_equal String, track.name.class, "The DAO should deal with arrays in returned tags."
    assert_equal "I Still Live With My Moms", track.name
    assert_equal String, track.genre.class, "The DAO should deal with arrays in returned tags."
    assert_equal "Indie Rap", track.genre
    assert_equal Fixnum, track.sequence.class, "The DAO should deal with arrays in returned tags."
    assert_equal 14, track.sequence
  end
  
  def test_capitalization_of_titles
    track = Track.new("IGNORED")
    
    track.artist_name = "alien sex fiend"
    track.name = "i walk the line"
    track.remix = "nonexistent mix"
    track.featured_artists << 'MC batcaver'
    track.genre = "goth rock"
    
    track.capitalize_names!
    
    assert_equal "Alien Sex Fiend", track.artist_name
    assert_equal "I Walk The Line", track.name
    assert_equal "Nonexistent mix", track.remix
    assert_equal "MC Batcaver", track.featured_artists.first
    assert_equal "Goth Rock", track.genre
  end
  
  def test_track_sort_order
    track = load_track('Various Artists/The Crow OST/Pantera - The Crow OST - 09 - The Badge.mp3')
    assert_equal 'The Badge', track.name
    assert_equal 'Badge, The', track.sort_order

    track = load_track('Various Artists/The Crow OST/The Cure - The Crow OST - 01 - Burn.mp3')
    assert_equal 'The Cure', track.artist_name
    assert_equal 'Cure, The', track.artist_sort_order
  end
end

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))

require 'test/unit'
require 'dao/track_dao'

class TrackTest < Test::Unit::TestCase
  def test_basic_track_instantiation_from_path
    track = load_track('zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3')

    assert_equal ':zoviet*france:', track.artist_name
    assert_equal 'Experimental', track.genre
    assert_equal 7, track.sequence
    assert_equal 'RIPT with GRIP', track.comment
  end
  
  def test_featured_artist_parsing
    track = load_track('Razor X Productions/Killing Sound [disc 1]/Razor X Productions - Killing Sound [disc 1] - 05 - Boom Boom Claat (feat. Cutty Ranks).mp3')

    assert_equal 1, track.featured_artists.size, "Load process should have found 1 featured artist."
    assert_equal 'Cutty Ranks', track.featured_artists.first
    assert_equal 'Boom Boom Claat', track.name, "Cutty Ranks should be removed from track name {#{track.name}}"
  end
  
  def test_standard_remix_parsing
    track = load_track('Aphex Twin/Ventolin/Aphex Twin - Ventolin - 01 - Ventolin Salbutamol Mix.mp3')

    assert_equal 'Ventolin', track.name
    assert_equal 'Salbutamol Mix', track.remix, "Salbutamol Mix should be removed from track name {#{track.name}}"
  end
  
  def test_nonstandard_remix_parsing
    track = load_track('Aphex Twin/Richard D James Album/Aphex Twin - Richard D James Album - 13 - GirlBoy Song 18 Snarerush Mix.mp3')

    assert_equal 'Girl/Boy Song', track.name
    assert_equal '£18 Snarerush Mix', track.remix, "£18 Snarerush Mix should be removed from track name {#{track.name}}"
    
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
  
  private

  def load_track(path)
    track_path = find_file(path)
    TrackDao.new(track_path).load_track(track_path)
  end

  def find_file(path)
    File.join(File.expand_path('../../mp3info/sample-metadata'), path)
  end
end

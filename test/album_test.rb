$: << File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require 'test/unit'
require 'album'
require 'dao/album_dao'

class AlbumTest < Test::Unit::TestCase
  def setup
    @album = Album.new
  end

  def test_default_album_constructor
    assert_equal 0, @album.discs.size
  end

  def test_default_album_from_path
    track_path = [ '../../mp3info/sample-metadata/zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3' ]
    albums = AlbumDao.load_albums_from_paths(track_path)

    assert_equal 1, albums.first.number_of_discs_loaded
    assert_equal 1, albums.first.discs[3].tracks.length
    assert_equal 'Charm Aliso', albums.first.discs[3].tracks.first.name
    assert_equal 7, albums.first.discs[3].tracks.first.sequence
    assert_equal 3, albums.first.discs[3].number
  end
  
  def test_assemble_album_from_files
    albums = load_albums("zovietfrance/*/*.mp3")

    assert_equal 1, albums.size, 'Three discs, but one album.'
    album = albums.first
    assert_equal 3, album.number_of_discs_loaded
    assert_equal 10, album.discs[1].number_of_tracks_loaded
    assert_equal 18, album.discs[2].number_of_tracks_loaded
    assert_equal 9, album.discs[3].number_of_tracks_loaded
    assert_equal 37, album.number_of_tracks_loaded
    assert_equal ':zoviet*france:', album.artist_name
    assert_equal 'Popular Soviet Songs And Youth Music', album.name
    assert_equal 'Experimental', album.genre
  end

  def test_assemble_album_before_tags_canonicalized
    albums = load_albums("Razor X Productions/*/*.mp3")

    assert_equal 1, albums.size, 'Two discs, but one album (names need to be fixed).'
    album = albums.first
    assert_equal 2, album.number_of_discs_loaded, 'One album, two discs.'
    assert_equal 10, album.discs[1].number_of_tracks_loaded
    assert_equal 10, album.discs[2].number_of_tracks_loaded
    assert_equal 20, album.number_of_tracks_loaded
    assert_equal 'Razor X Productions', album.artist_name
    assert_equal 'Killing Sound', album.name
    assert_equal 'Dancehall', album.genre
  end

  def test_assemble_compilation_with_unicode_tags
    albums = load_albums("Various Artists/The Biggest Ragga Dancehall Anthems 2005/*.mp3")

    assert_equal 1, albums.size
    album = albums.first
    assert_equal 1, album.number_of_discs_loaded
    assert_equal 40, album.discs[1].number_of_tracks_loaded
    assert_equal 40, album.number_of_tracks_loaded
    assert_equal 'Various Artists', album.artist_name
    assert_equal 'The Biggest Ragga Dancehall Anthems 2005', album.name
    
    tracks = album.discs[1].tracks.sort { |first,second| first.sequence <=> second.sequence }
    assert_equal 'Vybz Kartel', tracks[0].artist_name
    assert_equal 'Who Dem A Talk', tracks[39].name
    assert_equal 'Dancehall', album.genre
  end

  def test_assemble_album_from_2_2_tags_with_old_itunes_filenames
    albums = load_albums("Keith Fullerton Whitman/Multiples/*.mp3")

    assert_equal 1, albums.size
    album = albums.first
    assert_equal 1, album.number_of_discs_loaded
    assert_equal 8, album.discs[1].number_of_tracks_loaded
    assert_equal 8, album.number_of_tracks_loaded
    assert_equal 'Keith Fullerton Whitman', album.artist_name
    assert_equal 'Multiples', album.name
    assert_equal 'Ambient', album.genre
  end
  
  def test_convert_RIPT_w_GRIP_from_comment_to_encoder
    albums = load_albums("1349/Liberation/*.mp3")

    album = albums.first
    assert_equal 10, album.number_of_tracks_loaded
    album.discs.compact.each do |disc|
      disc.tracks.each do |track|
        assert track.encoder.join(' / ') =~ /RIPT with GRIP/,
               "RIPT with GRIP comment should have moved to track for #{track.name}"
        assert_nil track.comment,
               "Encoder should have been cleared out" 
      end
    end
  end
  
  def test_find_mixer_name
    albums = load_albums("Boredoms/Rebore Vol 3 mixed by DJ Krush/*.mp3")

    album = albums.first
    assert_equal 'Rebore Vol. 3', album.name
    assert_equal 'DJ Krush', album.mixer
  end
  
  def test_album_release_date
    albums = load_albums("324/Boutokunotaiyo/*.mp3")

    album = albums.first
    assert_equal '2002', album.release_date
  end
  
  def test_album_find_hidden_soundtrack
    albums = load_albums("Various Artists/The Crow OST/*.mp3")

    album = albums.first
    assert_equal 'The Crow', album.name
    assert_equal 'Soundtrack', album.genre
    album.discs.compact.each do |disc|
      disc.tracks.each do |track|
        assert_equal album.genre, track.genre
      end
    end
  end
  
  def test_album_musicbrainz_metadata
    albums = load_albums("324/Boutokunotaiyo/*.mp3")

    album = albums.first
    assert_equal 'd5b75c8e-ae03-4b00-934a-af2668339f48', album.musicbrainz_album_id
    assert_equal 'album', album.musicbrainz_album_type
    assert_equal 'official', album.musicbrainz_album_status
  end
  
  def test_totally_confused_album
    albums = load_albums("Artist Of Confusion/Album Of Confusion*/*.mp3")

    assert_equal 5, albums.size
    
    track_list = albums.collect{|album| album.discs.compact.collect{|disc| disc.tracks}}.flatten.compact
    assert_equal 6, track_list.size
    
    zf = track_list.select { |track| 'Charm Aliso' == track.name }
    assert_equal 1, zf.size, "Should only find one track."
    assert_equal 3, zf.first.disc.number, ":z*f: show up on third disc despite filename cuz of ID3v2 tag."
    
    ijctsily = track_list.select { |track| 'I Just Called To Say I Love You' == track.name }
    assert_equal 2, ijctsily.first.disc.number, "Stevie's on disc 2 because there's no disc info in his tag."
  end
  
  def test_dispersed_album
    albums = load_albums("Artist Of Dispersion/Dispersed disc*/*.mp3")

    assert_equal 1, albums.size
    album = albums.first
    
    assert_equal 1, album.number_of_discs
    assert_equal 1, album.number_of_discs_loaded
    
    assert_equal 14, album.number_of_tracks
    assert_equal 14, album.number_of_tracks_loaded
    
    assert_equal "324", album.artist_name

    track_list = albums.collect{|album| album.discs.compact.collect{|disc| disc.tracks}}.flatten.compact
    assert !track_list.detect { |track| '324' != track.artist_name }
  end
  
  def test_album_display
    sample_output =<<END
[2006] Razor X Productions: Killing Sound (Dancehall)

  Disc 1:
    1.1: Killer
                     Featured: He-Man
    1.2: WWW
                     Featured: Mexican
    1.3: Slew Dem
                     Featured: Wayne Lonesome
    1.4: Child Molester
                     Featured: Mexican
    1.5: Boom Boom Claat
                     Featured: Cutty Ranks
    1.6: Imitator
                     Featured: Daddy Freddy
    1.7: War Start
                     Featured: Bongo Chilli
    1.8: Yard Man
                     Featured: El Feco
    1.9: I Don't Know
                     Featured: Tony Tuff
    1.10: Killer Queen
                     Featured: Warrior Queen
  Disc 2:
    2.1: Kill Version
    2.2: W Version
    2.3: Slew Version
    2.4: Child Version
    2.5: Boom Version
    2.6: Imitate Version
    2.7: Problem Version
    2.8: Start Version
    2.9: Yard Version
    2.10: Don't Version

Encoded by Exact Audio Copy (secure mode)
           lame 3.96.1 --alt-preset standard
           ::AOAIOXXYSZ:: encoding tools, v1

END
    
    albums = load_albums("Razor X Productions/*/*.mp3")
    album = albums.first
    assert_equal sample_output, album.display_formatted
  end
  
  def test_capitalization_of_titles
    album = Album.new
    
    album.artist_name = "alien sex fiend"
    album.name = "too much acid? NO SUCH THING!"
    album.genre = "goth rock"
    album.mixer = "homicidal MC"
    
    album.capitalize_names!
    
    assert_equal "Alien Sex Fiend", album.artist_name
    assert_equal "Too Much Acid? NO SUCH THING!", album.name
    assert_equal "Goth Rock", album.genre
    assert_equal "Homicidal MC", album.mixer
  end
  
  private
  
  def load_albums(path)
    album_paths = find_files(path)
    AlbumDao.load_albums_from_paths(album_paths)
  end

  def find_files(path)
    Dir.glob(File.join(File.expand_path('../../mp3info/sample-metadata'), path))
  end
end


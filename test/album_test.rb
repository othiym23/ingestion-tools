$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))

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

    assert_equal 1, albums.first.number_of_discs
    assert_equal 1, albums.first.discs[3].tracks.length
    assert_equal 'Charm Aliso', albums.first.discs[3].tracks.first.name
    assert_equal 7, albums.first.discs[3].tracks.first.sequence
    assert_equal 3, albums.first.discs[3].tracks.first.disc_number
  end
  
  def test_assemble_album_from_files
    albums = load_albums("zovietfrance/*/*.mp3")

    assert_equal 1, albums.size, 'Three discs, but one album.'
    album = albums.first
    assert_equal 3, album.number_of_discs
    assert_equal 9, album.discs[1].number_of_tracks
    assert_equal 9, album.discs[2].number_of_tracks
    assert_equal 9, album.discs[3].number_of_tracks
    assert_equal 27, album.number_of_tracks
    assert_equal ':zoviet*france:', album.artist_name
    assert_equal 'Popular Soviet Songs And Youth Music', album.name
    assert_equal 'Experimental', album.genre
  end

  def test_assemble_album_from_precanonicalized_tags
    albums = load_albums("Razor X Productions/*/*.mp3")

    assert_equal 1, albums.size, 'Two discs, but one album (names need to be fixed).'
    album = albums.first
    assert_equal 2, album.number_of_discs, 'One album, two discs.'
    assert_equal 10, album.discs[1].number_of_tracks
    assert_equal 10, album.discs[2].number_of_tracks
    assert_equal 20, album.number_of_tracks
    assert_equal 'Razor X Productions', album.artist_name
    assert_equal 'Killing Sound', album.name
    assert_equal 'Dancehall', album.genre
  end

  def test_assemble_compilation_with_unicode_tags
    albums = load_albums("Various Artists/The Biggest Ragga Dancehall Anthems 2005/*.mp3")

    assert_equal 1, albums.size
    album = albums.first
    assert_equal 1, album.number_of_discs
    assert_equal 40, album.discs[1].number_of_tracks
    assert_equal 40, album.number_of_tracks
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
    assert_equal 1, album.number_of_discs
    assert_equal 8, album.discs[1].number_of_tracks
    assert_equal 8, album.number_of_tracks
    assert_equal 'Keith Fullerton Whitman', album.artist_name
    assert_equal 'Multiples', album.name
    assert_equal '(26)', album.genre
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


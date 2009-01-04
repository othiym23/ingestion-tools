$: << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))

require 'fileutils'

require 'test/unit'
require 'dao/album_dao'

class TrackValidator
  attr_accessor :artist_name, :genre, :number_of_discs, :number_of_tracks, :disc_path_prefixes
  
  SIZE_DELTA = 5120
  
  def initialize(parent_test, artist_name, genre, number_of_discs,
                 disc_path_prefixes, number_of_tracks_list)
    @parent_test = parent_test
    @artist_name = artist_name
    @genre = genre
    @number_of_discs = number_of_discs
    @disc_path_prefixes = disc_path_prefixes
    @number_of_tracks = number_of_tracks_list
  end
  
  def validate(track, size, disc_number, track_number, filename, featured_artist = nil)
    @parent_test.assert_equal disc_number, track.disc.number,
                              "disc numbers should match for '#{filename}'"
    @parent_test.assert_equal @number_of_discs, track.disc.album.number_of_discs,
                              "numbers of discs should match for '#{filename}'"
    @parent_test.assert_equal track_number, track.sequence,
                              "track numbers should match for '#{filename}'"
    @parent_test.assert_equal @number_of_tracks[disc_number - 1], track.disc.number_of_tracks,
                              "numbers of tracks per disc should match for '#{filename}'"
    @parent_test.assert_equal @genre, track.genre,
                              "genres should match for '#{filename}'h"
    @parent_test.assert_equal @artist_name, track.artist_name,
                              "artist names should match for '#{filename}'"
    @parent_test.assert_equal File.join(@disc_path_prefixes[disc_number - 1], filename), track.path,
                              "paths should match"
    if featured_artist
      @parent_test.assert track.featured_artists.detect { |artist| featured_artist == artist },
                          "artist #{featured_artist} should be featured but isn't for '#{filename}'"
    end
    
    @parent_test.assert_in_delta size, File.stat(track.path).size, SIZE_DELTA,
                                 "changing the ID3 tag size shouldn't mangle things much for '#{filename}'"
  end
end

# the most scary set of tests in the system: writing corrected MP3 files!
class AlbumWriteTest < Test::Unit::TestCase
  def setup
    @staging_root = File.expand_path(File.join(File.dirname(__FILE__), 'staging'))
    @processed_root = File.expand_path(File.join(File.dirname(__FILE__), 'processed'))
  end
  
  def test_integrated_write_album
    begin
      source_root = File.expand_path(File.join(File.dirname(__FILE__), 'sample_files'))

      FileUtils.cp_r(source_root, @staging_root)
      
      source_paths = find_mp3_files(@staging_root)
      assert_equal 20, source_paths.size,
                   "there were 20 MP3 files when I started -- why aren't there now?"

      albums = AlbumDao.load_albums_from_paths(source_paths)
      assert_equal 1, albums.size, "there's only 1 album here"
      
      album = albums.first
      assert_equal 2, album.number_of_discs
      assert_equal 2, album.number_of_discs_loaded
      
      album_dao = AlbumDao.new(@processed_root)
      warnings = album_dao.archive_album(album)
      assert_equal 0, warnings.size,
                   "there should be no warnings, instead we got #{warnings.join('; ')}"
      
      assert !File.exists?(File.join(@staging_root, 'Razor X Productions')),
             "after archiving, empty directories should be removed"
      
      archived_paths = find_mp3_files(@processed_root)
      assert_equal 20, archived_paths.size,
                   "there were originally 20 tracks, should be 20 now"
      
      archived_albums = AlbumDao.load_albums_from_paths(archived_paths)
      assert_equal 1, archived_albums.size, "there was only 1 album to begin with"
      
      archived_album = archived_albums.first
      assert_equal 2, archived_album.number_of_discs,
                   "album DAO should correct the number of discs automatically"
      assert_equal 2, archived_album.number_of_discs_loaded
      
      track_checker = TrackValidator.new(self, 'Razor X Productions', 'Dancehall', 2,
                                         [File.join(@processed_root, 'Razor X Productions/Killing Sound disc 1'),
                                          File.join(@processed_root, 'Razor X Productions/Killing Sound disc 2')],
                                         [10, 10])
      
      archived_album.tracks.each do |track|
        case track.name
        when 'Killer'
          track_checker.validate(track, 4708122, 1, 1,
                                 'Razor X Productions - Killing Sound - 01 - Killer feat HeMan.mp3',
                                 'He-Man')
        when 'WWW'
          track_checker.validate(track, 5892223, 1, 2,
                                 'Razor X Productions - Killing Sound - 02 - WWW feat Mexican.mp3',
                                 'Mexican')
        when 'Slew Dem'
          track_checker.validate(track, 5741745, 1, 3,
                                 'Razor X Productions - Killing Sound - 03 - Slew Dem feat Wayne Lonesome.mp3',
                                 'Wayne Lonesome')
        when 'Child Molester'
          track_checker.validate(track, 5590345, 1, 4,
                                 'Razor X Productions - Killing Sound - 04 - Child Molester feat Mexican.mp3',
                                 'Mexican')
        when 'Boom Boom Claat'
          track_checker.validate(track, 5221219, 1, 5,
                                 'Razor X Productions - Killing Sound - 05 - Boom Boom Claat feat Cutty Ranks.mp3',
                                 'Cutty Ranks')
        when 'Imitator'
          track_checker.validate(track, 6230344, 1, 6,
                                 'Razor X Productions - Killing Sound - 06 - Imitator feat Daddy Freddy.mp3',
                                 'Daddy Freddy')
        when 'War Start'
          track_checker.validate(track, 5455934, 1, 7,
                                 'Razor X Productions - Killing Sound - 07 - War Start feat Bongo Chilli.mp3',
                                 'Bongo Chilli')
        when 'Yard Man'
          track_checker.validate(track, 5554023, 1, 8,
                                 'Razor X Productions - Killing Sound - 08 - Yard Man feat El Feco.mp3',
                                 'El Feco')
        when 'I Don\'t Know'
          track_checker.validate(track, 4814031, 1, 9,
                                 'Razor X Productions - Killing Sound - 09 - I Dont Know feat Tony Tuff.mp3',
                                 'Tony Tuff')
        when 'Killer Queen'
          track_checker.validate(track, 5212905, 1, 10,
                                 'Razor X Productions - Killing Sound - 10 - Killer Queen feat Warrior Queen.mp3',
                                 'Warrior Queen')
        when 'Kill Version'
          track_checker.validate(track, 5023012, 2, 1,
                                 'Razor X Productions - Killing Sound - 01 - Kill Version.mp3')
        when 'W Version'
          track_checker.validate(track, 6969521, 2, 2,
                                 'Razor X Productions - Killing Sound - 02 - W Version.mp3')
        when 'Slew Version'
          track_checker.validate(track, 6205221, 2, 3,
                                 'Razor X Productions - Killing Sound - 03 - Slew Version.mp3')
        when 'Child Version'
          track_checker.validate(track, 5869024, 2, 4,
                                 'Razor X Productions - Killing Sound - 04 - Child Version.mp3')
        when 'Boom Version'
          track_checker.validate(track, 5597642, 2, 5,
                                 'Razor X Productions - Killing Sound - 05 - Boom Version.mp3')
        when 'Imitate Version'
          track_checker.validate(track, 6836577, 2, 6,
                                 'Razor X Productions - Killing Sound - 06 - Imitate Version.mp3')
        when 'Problem Version'
          track_checker.validate(track, 4353368, 2, 7,
                                 'Razor X Productions - Killing Sound - 07 - Problem Version.mp3')
        when 'Start Version'
          track_checker.validate(track, 6000019, 2, 8,
                                 'Razor X Productions - Killing Sound - 08 - Start Version.mp3')
        when 'Yard Version'
          track_checker.validate(track, 5672284, 2, 9,
                                 'Razor X Productions - Killing Sound - 09 - Yard Version.mp3')
        when 'Don\'t Version'
          track_checker.validate(track, 5666183, 2, 10,
                                 'Razor X Productions - Killing Sound - 10 - Dont Version.mp3')
        else
          fail "Track '#{track.name}'' isn't supposed to be part of this release."
        end
      end
    ensure
      clean_paths
    end
  end
  
  def test_writing_album_should_not_truncate_files
    begin
      source_root = File.expand_path(File.join(File.dirname(__FILE__), 'sample_files_2'))

      FileUtils.cp_r(source_root, @staging_root)
      
      source_paths = find_mp3_files(@staging_root)
      assert_equal 9, source_paths.size,
                   "there were 20 MP3 files when I started -- why aren't there now?"

      albums = AlbumDao.load_albums_from_paths(source_paths)
      assert_equal 1, albums.size, "there's only 1 album here"
      
      album = albums.first
      assert_equal 1, album.number_of_discs
      assert_equal 1, album.number_of_discs_loaded
      
      album.name = "Peter Gabriel [car]"
      album.genre = "Progressive Rock"
      
      album_dao = AlbumDao.new(@processed_root)
      
      warnings = album_dao.archive_album(album)
      assert_equal 0, warnings.size,
                   "there should be no warnings, instead we got #{warnings.join('; ')}"
      
      assert !File.exists?(File.join(@staging_root, 'Peter Gabriel')),
             "after archiving, empty directories should be removed"
      
      archived_paths = find_mp3_files(@processed_root)
      assert_equal 9, archived_paths.size,
                   "there were originally 20 tracks, should be 20 now"
      
      archived_albums = AlbumDao.load_albums_from_paths(archived_paths)
      assert_equal 1, archived_albums.size, "there was only 1 album to begin with"
      
      archived_album = archived_albums.first
      assert_equal 1, archived_album.number_of_discs,
                   "album DAO should correct the number of discs automatically"
      assert_equal 1, archived_album.number_of_discs_loaded
      
      track_checker = TrackValidator.new(self, 'Peter Gabriel', 'Progressive Rock', 1,
                                         [File.join(@processed_root, 'Peter Gabriel/Peter Gabriel car')],
                                         [9])
      
      archived_album.tracks.each do |track|
        case track.name
        when 'Moribund The Burgemeister'
          track_checker.validate(track, 6989662, 1, 1,
                                 'Peter Gabriel - Peter Gabriel car - 01 - Moribund The Burgemeister.mp3')
        when 'Solsbury Hill'
          track_checker.validate(track, 8667768, 1, 2,
                                 'Peter Gabriel - Peter Gabriel car - 02 - Solsbury Hill.mp3')
        when 'Modern Love'
          track_checker.validate(track, 5744066, 1, 3,
                                 'Peter Gabriel - Peter Gabriel car - 03 - Modern Love.mp3')
        when 'Excuse Me'
          track_checker.validate(track, 5889844, 1, 4,
                                 'Peter Gabriel - Peter Gabriel car - 04 - Excuse Me.mp3')
        when 'Humdrum'
          track_checker.validate(track, 6041655, 1, 5,
                                 'Peter Gabriel - Peter Gabriel car - 05 - Humdrum.mp3')
        when 'Slowburn'
          track_checker.validate(track, 7655288, 1, 6,
                                 'Peter Gabriel - Peter Gabriel car - 06 - Slowburn.mp3')
        when 'Waiting For The Big One'
          track_checker.validate(track, 12018047, 1, 7,
                                 'Peter Gabriel - Peter Gabriel car - 07 - Waiting For The Big One.mp3')
        when 'Down The Dolce Vita'
          track_checker.validate(track, 8934480, 1, 8,
                                 'Peter Gabriel - Peter Gabriel car - 08 - Down The Dolce Vita.mp3')
        when 'Here Comes The Flood'
          track_checker.validate(track, 9212525, 1, 9,
                                 'Peter Gabriel - Peter Gabriel car - 09 - Here Comes The Flood.mp3')
        else
          fail "Track '#{track.name}'' isn't supposed to be part of this release."
        end
      end
    ensure
      clean_paths
    end
  end
  
  private
  
  def find_mp3_files(start_path)
    Dir.glob("#{start_path + File::SEPARATOR}**#{File::SEPARATOR}*.mp3")
  end
  
  def clean_paths
    FileUtils.rmtree([@staging_root, @processed_root])
  end
end

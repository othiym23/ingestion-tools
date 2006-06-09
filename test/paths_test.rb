$: << File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require 'test/unit'
require 'path_utils'

class PathsTest < Test::Unit::TestCase
  def test_path_has_mp3
    assert PathUtils.valid_mp3_path?('./Eminem/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.mp3'),
           "Gotta be able to recognize a valid path when we see it"
    assert PathUtils.valid_mp3_path?('./relocated base/Eminem/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.mp3'),
           "Gotta be able to recognize a valid path when we see it, even a few dirs down"
  end
  
  def test_recognize_invalid_path
    assert !PathUtils.valid_mp3_path?('./Eminem/Curtain Call/Eminem - Encore - 01 - Curtains Up Encore Version.mp3'),
           "Gotta be able to recognize an invalid path (with mismatched album) when we see it"
    assert !PathUtils.valid_mp3_path?('./Eminem/Encore/Eminem - Encore - 01 - Curtains Up (Encore Version).mp3'),
           "Gotta be able to recognize an invalid path (with invalid characters) when we see it"
  end
  
  def test_recognize_split_album
    assert PathUtils.valid_mp3_path?('./Xasthur  Leviathan/Xasthur  Leviathan/Xasthur - Xasthur  Leviathan - 02 - Keeper Of Sharpened Blades And Ominous Fates.mp3'),
           "Gotta be able to recognize a valid path for a split album."
    assert PathUtils.valid_mp3_path?('./The Clash/The Story Of The Clash/Clash - The Story Of The Clash - 02 - Should I Stay Or Should I Go.mp3'),
           "Gotta be able to recognize a valid path for a split album without getting confused by artist name mismatch."
  end
  
  def test_recognize_multi_disc
    assert PathUtils.valid_mp3_path?('./zovietfrance/Popular Soviet Songs And Youth Music disc 3/zovietfrance - Popular Soviet Songs And Youth Music - 07 - Charm Aliso.mp3'),
           "Gotta be able to recognize a valid path for a multi-disc album."
  end
  
  def test_unrecognized_file_type
    assert !PathUtils.valid_mp3_path?('./Eminem/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.aac'),
           "Gotta fail on unrecognized file types without causing errors."
  end
  
  def test_path_artist_is_compilation
    assert PathUtils.valid_mp3_path?('./Various Artists/Encore/Eminem - Encore - 01 - Curtains Up Encore Version.mp3'),
           "Various Artists albums get a special pass."
  end
  
  def test_safe_move_moves_safely
    sample_src = "./FILEMOVE_old.txt"
    sample_dest = "./FILEMOVE_new.txt"
    
    File.open(sample_src, "w") do |file|
      file.puts "TEST"
    end
    assert File.exists?(sample_src)
    
    PathUtils.safe_move(sample_src, sample_dest)
    
    assert File.exists?(sample_dest), "The file should be moved to its destination now"
    assert_equal 'TEST', File.open(sample_dest) { |file| file.gets.chomp }, "Contents of moved file should remain unchanged."
    assert !File.exists?(".#{sample_dest}-new"), "Intermediate file should be gone."
    assert !File.exists?(sample_src), "Old location should no longer exist."
    
    File.delete(sample_dest) if File.exists?(sample_dest)
  end
  
  def test_safe_move_wont_overwrite_existing
    sample_src = "./FILEMOVE_old.txt"
    sample_dest = "./FILEMOVE_new.txt"
    
    File.open(sample_src, "w") do |file|
      file.puts "TEST 1"
    end
    assert File.exists?(sample_src)
    
    File.open(sample_dest, "w") do |file|
      file.puts "TEST 2"
    end
    assert File.exists?(sample_dest)
    
    assert_raise(IOError) { PathUtils.safe_move(sample_src, sample_dest) }
    assert !File.exists?(".#{sample_dest}-new"), "Intermediate file should be gone."
    
    File.delete(sample_src) if File.exists?(sample_src)
    File.delete(sample_dest) if File.exists?(sample_dest)
  end

  def test_safe_move_creates_new_path
    sample_src = "./FILEMOVE_old.txt"
    sample_path = "./test_FILEMOVE/path/to/file"
    sample_dest = "#{sample_path}/FILEMOVE_new.txt"
    
    File.open(sample_src, "w") do |file|
      file.puts "TEST 1"
    end
    assert File.exists?(sample_src), "sample source file should be created without problems."
    
    PathUtils.safe_move(sample_src, sample_dest)
    assert File.exists?(sample_path), "new dest directory should be created"
    assert File.exists?(sample_dest), "new sample file should be created"
    assert !File.exists?(File.dirname(sample_dest) + File::SEPARATOR + ".#{File.basename(sample_dest)}-new"), "Intermediate file should be gone."
    assert !File.exists?(sample_src), "Old location should no longer exist."
    
    FileUtils.rmtree('./test_FILEMOVE') if File.exists?('./test_FILEMOVE')
  end
end

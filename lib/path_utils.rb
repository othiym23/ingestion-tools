require File.join(File.dirname(__FILE__), 'track_metadata')
require 'fileutils'

class PathUtils
  def PathUtils.valid_mp3_path?(path)
    if (mp3_file? File.basename(path)) && (path_canonical? path)

      file_track = TrackFilenameMetadata.new(path)
      path_track = TrackPathMetadata.new(path)
      
      if ('.' == File.dirname(path).split(File::SEPARATOR)[0]) &&
         (file_track.album_name == path_track.album_name) &&
         ((file_track.artist_name == path_track.artist_name) ||
           path_track.compilation? ||
           track_from_split?(path_track, file_track))
        true
      else
        false
      end
    else
      false
    end
  end

  def PathUtils.safe_copy(src_path, dest_path)
    unless File.exists?(File.dirname(dest_path))
      FileUtils.mkdir_p(File.dirname(dest_path))
    else
      # TODO: check for close matches
      # TODO: prompt if close matches exist
    end

    safe_target = File.join(File.dirname(dest_path), ".#{File.basename(dest_path)}-new")

    FileUtils.cp(src_path, safe_target)

    unless File.exists?(dest_path)
      File.rename(safe_target, dest_path)
    else
      File.delete(safe_target)
      raise IOError.new("Cannot safely copy file over existing file.")
    end
  end
  
  def PathUtils.safe_move(src_path, dest_path)
    safe_copy(src_path, dest_path)
    File.delete(src_path)
  end

  def PathUtils.canonicalize(path)
    path.gsub(/[^a-zA-Z0-9 .\/-]/, '')
  end
  
  def PathUtils.album_ingested?(archive_base, new_base)
    path_elements = new_base.split(File::SEPARATOR)
    artist_name = path_elements[-2]
    album_name = path_elements[-1]

    File.exists?(archive_base + File::SEPARATOR +
                 artist_name + File::SEPARATOR + 
                 album_name) ||
    File.exists?(archive_base + File::SEPARATOR +
                 artist_name + File::SEPARATOR + 
                 "The " + album_name)
  end

  private
  
  def PathUtils.mp3_file?(filename)
    return '.mp3' == File.extname(filename)
  end
  
  def PathUtils.path_canonical?(path)
    path == canonicalize(path)
  end
  
  def PathUtils.track_from_split?(path_track, file_track)
    if (path_track.artist_name.match(file_track.artist_name) &&
        !(file_track.artist_name == "The #{path_track.artist_name}"))
      true
    else
      false
    end
  end
end
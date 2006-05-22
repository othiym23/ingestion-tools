require File.join(File.dirname(__FILE__), 'track_metadata')

class Track
  attr_accessor :filename_metadata, :path_metadata
  
  def initialize(path_metadata, filename_metadata)
    @path_metadata = path_metadata
    @filename_metadata = filename_metadata
  end
  
  def Track.from_file(path)
    Track.new(TrackPathMetadata.new(path), TrackFilenameMetadata.new(path))
  end
end
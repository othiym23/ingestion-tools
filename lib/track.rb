class Track
  attr_reader :path
  
  attr_accessor :disc, :name, :artist_name, :album_name
  attr_accessor :sequence, :genre, :comment, :encoder
  
  def initialize(path)
    @path = path
  end
end
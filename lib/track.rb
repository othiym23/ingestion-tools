class Track
  attr_reader :path
  
  attr_accessor :album_name, :name, :artist_name
  attr_accessor :disc_number, :max_disc_number, :sequence, :max_sequence
  attr_accessor :genre, :comment, :encoder
  
  def initialize(path)
    @path = path
  end
end
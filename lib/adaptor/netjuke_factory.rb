#$: << File.expand_path(File.join(File.dirname(__FILE__), '../../../../rails/netjuke-tlg'))

require File.expand_path(File.join(File.dirname(__FILE__), '../../../../rails/netjuke-tlg/config/boot'))

require 'base'
require 'artist'
require 'genre'
require 'album'
require 'track'

class Netjuke::GenreDao
  def self.find_related_genres(raw_genre)
    Netjuke::Genre.find_generously(raw_genre)
  end
  
  def self.find_genre(genre_name)
    Netjuke::Genre.find_by_name(genre_name)
  end
end

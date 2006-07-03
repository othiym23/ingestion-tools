require 'ui/selection_model'
require 'adaptor/euterpe_dashboard_factory'

class AlbumSelectionModel < SelectionModel
  attr_accessor :status
  
  def initialize
    @narrowing_terms = []
  end
  
  def selected=(album)
    if album
      @status.message = "reloading metadata for #{album.artist_name} - #{album.name}"
      album = AlbumDao.reload_album_from_files(album)
    end
    
    super(album)
  end
  
  def narrowed_list
    @narrowed_list || @list
  end
  
  def narrow(term)
    unless term.nil?
      @narrowing_terms.push term
      
      changed
      if @list.nil?
        @list = narrow_albums([], term)
      else
        narrowed_list = @list
        @narrowing_terms.each do |term|
          narrowed_list = narrow_albums(narrowed_list, term)
        end
        
        if 1 == narrowed_list.size
          @narrowing_terms.pop
          self.selected = narrowed_list.first
          @status.message = "#{narrowed_list.size} found"
        else
          if @narrowed_list != narrowed_list
            @narrowed_list = narrowed_list
            @status.message = "#{narrowed_list.size} found"
          end
        end
      end
      
      notify_observers(term)
    end
  end
  
  def clear_narrowing!
    @narrowed_list = nil
    @narrowing_terms = [@narrowing_terms.first] if @narrowing_terms.size > 1
    changed
    notify_observers
  end
  
  def reset_list!
    @narrowing_terms = []
    @narrowed_list = nil
    @list = nil
    changed
    notify_observers
  end
  
  private
  
  def narrow_albums(albums, search_term)
    if [] == albums
      if search_term && '' != search_term.strip
        AlbumDao.find_generously(search_term)
      end
    else
      albums.select do |album|
        album_name = "#{album.artist_name}: #{album.name}"
        
        album.artist_name.match(/#{search_term}/i) ||
        album.name.match(/#{search_term}/i) ||
        album.genre.match(/#{search_term}/i) ||
        album.discs.compact.detect do |disc|
          disc.tracks.detect do |track|
            track.artist_name.match(/#{search_term}/i) ||
            track.name.match(/#{search_term}/i) ||
            track.genre.match(/#{search_term}/i)
          end
        end
      end
    end
  end
end

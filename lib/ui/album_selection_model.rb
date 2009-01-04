require 'ui/selection_model'
require 'adaptor/euterpe_dashboard_factory'

class AlbumSelectionModel < SelectionModel
  attr_writer :status
  attr_reader :archiving_queue
  
  def initialize(album_loader, logger)
    @album_loader = album_loader
    @logger = logger

    @narrowing_terms = []
    @archiving_queue = []
  end
  
  def selected=(album)
    if album
      @status.message = "reloading metadata for #{album.artist_name} - #{album.name}"
      @logger.debug('selected=') { "reloading metadata for #{album.artist_name} - #{album.name}" }
      
      metadata_album = AlbumDao.reload_album_from_files(album)
      metadata_album.cached_album = album.cached_album
      metadata_album.original_album = album
      @logger.debug('selected=') { "after reloading have #{metadata_album.artist_name} - #{metadata_album.name}" }
    end
    
    super(metadata_album)
    @logger.debug('selected=') { "selected is now #{selected.artist_name} - #{selected.name}"} if @selected
    metadata_album
  end
  
  def narrowed_list
    # if the underlying list has been modified, we need to refresh the narrowed list
    if @narrowed_list && (@narrowed_list.size > @list.size)
      @narrowed_list = @list
      MY_LOGGER.debug("narrowed list refreshed")
    end
    
    @narrowed_list = nil if @narrowed_list && (@narrowed_list.size == 0)
    
    (@narrowed_list || @list || []) - (@archiving_queue || [])
  end
  
  def narrow(term)
    unless term.nil?
      @narrowing_terms.push term
      
      changed
      if @list.nil?
        @narrowing_terms = []
        @narrowed_list = nil
        
        raw_list = narrow_albums([], term)
        @logger.debug('narrow') { "got from narrowing #{raw_list} with a size of #{raw_list ? raw_list.size : 0}"}
        
        if raw_list && 1 == raw_list.size
          @logger.debug('narrow') { "single result found, setting selection"}
          self.selected = raw_list.first
        else
          @list = raw_list
        end
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

  def will_archive(album)
    @archiving_queue.push(album)
  end
  
  def has_archived(album)
    @archiving_queue.delete(album)
  end

  private
  
  def narrow_albums(albums, search_term)
    if [] == albums
      if search_term && '' != search_term.strip
        @logger.debug('narrow_albums') { "searching metadata cache for '#{search_term}'"}
        generous_results = @album_loader.find_generously(search_term)
        @logger.debug('narrow_albums') { "metadata cache returns cached IDs #{generous_results.collect{|result| result.cached_album.id}.join(', ')}"}

        if @archiving_queue.size > 0
          @logger.debug('narrow_albums') { "archiving queue contains cached IDs #{@archiving_queue.collect{|result| result.cached_album.id}.join(', ')}"}
          curried_results = generous_results.reject { |result| @archiving_queue.detect { |enqueued| enqueued.cached_album.id == result.cached_album.id } }
          @logger.debug('narrow_albums') { "difference of queue and results is #{curried_results.collect{|result| result.cached_album.id}.join(', ')}"}
          curried_results
        else
          generous_results
        end
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

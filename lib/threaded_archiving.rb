require 'thread'
require 'dao/album_dao'

class ArchiveService
  def initialize(logger, status_widget, archive_base)
    @status = status_widget
    @log = logger
    @archive_base = archive_base
  end

  def archive_album(album)
    @status.message = "Archiving #{album.reconstituted_name}..."

    @log.info('ArchiveService') { "archiving #{album.reconstituted_name}" }
    AlbumDao.new(@archive_base).archive_album(album)
    @log.debug('ArchiveService') { "successfully archived #{album.reconstituted_name}" }
  end
end

class DatabaseService
  def initialize(logger)
    @log = logger
  end

  def purge_cached_album(album)
    @log.info('DatabaseService') { "purging #{album.reconstituted_name} from metadata cache" }
    AlbumDao.purge(album)
    @log.debug('DatabaseService') { "#{album.reconstituted_name} purged from metadata cache" }
  end
end

class AlbumArchiver
  attr_reader :archiver_thread
  
  def initialize(logger, status_widget, selection_model, archive_base, threaded=false)
    @logger = logger
    @status_widget = status_widget
    @selection_model = selection_model
    @archive_base = archive_base
    
    @threaded = threaded
    
    if @threaded
      @pending_albums = Queue.new
    else
      @pending_albums = []
    end
    
    @archive_service = ArchiveService.new(logger, status_widget, archive_base)
    @database_service = DatabaseService.new(logger)
    
    if threaded
      @archiver_thread = start_archiver
      @logger.info('Archiver') { "archiver thread started: #{@archiver_thread}, current thread: #{Thread.current}" }
    end
  end
  
  def archive_album(album)
    @logger.debug('archive_album') { "processing #{album.reconstituted_name}" }
    
    begin
      @status_widget.message = "Archiving #{album.reconstituted_name}..."
      @archive_service.archive_album(album)
      
      @status_widget.message = "Purging #{album.reconstituted_name} from cache..."
      @database_service.purge_cached_album(album)
    rescue AlbumAlreadyExistsException => chunder
      @logger.error('archive_album') { "Album was already in archive: #{chunder}" }
    rescue Exception => blargh
      @logger.error('archive_album') { "Something miscellaneously awful happened: #{blargh}" }
    end
    
    @selection_model.has_archived(album.original_album)
  end

  def queue_album(processed_album)
    @selection_model.will_archive(processed_album.original_album)
    @pending_albums.push(processed_album)
    @logger.info('queue_album') { "#{processed_album.artist_name} - #{processed_album.reconstituted_name} added to the queue for archiving" }
    @logger.info('queue_album') { "#{@pending_albums.size} albums currently in queue for archiving" }
    
    # this seems like an abuse of duck typing, but it works for now
    @logger.debug('queue_album') { "#{@pending_albums.num_waiting} threads waiting on queue" } if @threaded
  end
  
  def process_queue
    raise IOError.new("can only clear album queue when not running threaded") if @threaded
    
    @status_widget.message = "No albums to process!" unless @pending_albums.size > 0
    
    @logger.debug('process_queue') { "starting non-threaded archival process" }
    @pending_albums.each do |album|
      archive_album(album)
    end
    
    @pending_albums = []
    @status_widget.message = "All pending albums processed!"
    @logger.info('process_queue') { "all pending albums processed" }
  end
  
  private
  
  def start_archiver
    Thread.new do
      @logger.info('start_archiver') { "starting archiver thread" }
      
      loop do
        # Queue.pop blocks until it has something to return
        next_album = @pending_albums.pop
        archive_album(next_album)
      end
    end
  end
end

require 'ui/fln_widgets'

class PendingStatus < FLNBorderlessPane
  def initialize(selection_model, parent, top, width)
    MY_LOGGER.info("PendingStatus initialization started")
    self.model = selection_model
    super(parent, self.class.name, width - 26, top, 26, 1, '')
    self.color = JTTui.aaxz_basic
    MY_LOGGER.info("PendingStatus initialization complete")
  end

  def paintself(pc)
    message = current_message
    pc.move(self.w - message.length, 0)
    pc.addstra(message, JTTui.aaxz_important)
  end
  
  def model=(new_model)
    @model = new_model
    @model.add_observer(self)
  end
  
  def update(*args)
    addmessage self, :paint
  end

  def current_message
    message = @model.total.to_s << ' albums'
    if @model.selected
      message << ', 1 loaded'
    elsif @model.narrowed_list && @model.narrowed_list.size > 0
      message << ', ' << @model.narrowed_list.size.to_s << ' loaded'
    end
    
    message
  end
end

class GenericList < JTTWList
  def initialize(*args, &block)
    @totalwidth = 1
    super
    @color = JTTui.aaxz_basic
    @color_basic = JTTui.aaxz_basic
    @color_active = JTTui.aaxz_reversed
  end

  def current_item
    @content_list[@focusedentry] if @content_list
  end
  
  def content_list=(list)
    @content_list = list
    update
  end
  
  def content_string(idx)
    "#{"%03d" % (idx + 1)}. #{@content_list[idx]}" if @content_list
  end
  
  def update
    @totalwidth = 1
    @content_list.each_index{ |idx|
      cw = self.list_getitemsize(idx)[0]
      @totalwidth = cw if  cw > @totalwidth
    }
    updatescrollers
  end

  def list_getitemsize(idx)
    [self.w - 1, 1]
  end
  
  def list_drawitem(pc, hilighted, focused, idx)
    super(pc, hilighted, true, idx)
    pc.addstr content_string(idx)
  end

  def list_gettotalwidth
    @totalwidth
  end

  def list_getlength
    (@content_list.size if @content_list) || 0
  end

  def keypress(key)
    return false if list_keyonitem(key,@focusedentry)
    callupdate=true
    case key
    when 'up', 'C-p', 'u', 'k'   then step_minus
    when 'down', 'C-n', 'd', 'j' then step_plus
    when 'home', 'M-<'           then go_start
    when 'end', 'M->'            then go_end
    when 'pgup', 'M-v'           then view_minus
    when 'pgdn', 'C-v'           then view_plus

    when 'left', 'C-b'  then @scrollx.step_minus if @scrollx
    when 'right', 'C-f' then @scrollx.step_plus  if @scrollx
    when 'M-b'          then @scrollx.view_minus if @scrollx
    when 'M-f'          then @scrollx.view_plus  if @scrollx
    when 'C-a'          then @scrollx.go_start   if @scrollx
    when 'C-e'          then @scrollx.go_end     if @scrollx
    else
      callupdate=false
      addmessage @parent, :keypress, key
    end
    scrollaction if callupdate
  end

  def action
    @block.call(@content_list[@focusedentry]) if @block
  end
end

class AlbumList < GenericList
  def initialize(*args, &block)
    super
  end

  def current_album
    @album_list[@focusedentry] if @album_list
  end
  
  def album_list=(list)
    @album_list = list
    update
  end
  
  def album_string(idx)
    "#{"%03d" % (idx + 1)}. #{@album_list[idx].artist_name} - #{@album_list[idx].reconstituted_name}" if @album_list
  end
  
  def update
    @totalwidth = 1
    @album_list.each_index{ |idx|
      cw = self.list_getitemsize(idx)[0]
      @totalwidth = cw if  cw > @totalwidth
    }
    updatescrollers
  end
  
  def list_drawitem(pc, hilighted, focused, idx)
    super(pc, hilighted, true, idx)
    pc.addstr album_string(idx)
  end

  def list_getlength
    (@album_list.size if @album_list) || 0
  end

  def action
    @block.call(@album_list[@focusedentry]) if @block
  end
end

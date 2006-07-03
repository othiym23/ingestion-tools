require 'jttui/jttui'
require 'jttui/jttuistd'

class FLNBorderlessPane < JTTDialog
  def computeclientarea
    JTRectangle.new 0, 0, w, h
  end
  
  def paintself(pc)
    delmessages self,:paint
    pc.fillrect 0, 0, w, h, ?\s|@color
    pc.move 0,0
  end
end

# This class should not be used lightly, as it totally violates the
# carefully-maintained paint model created by JTTui. Sometimes you just
# wanna know what's going on, though
class FLNImmediateLabel < JTTWLabel
  def initialize(*args, &block)
    super(*args, &block)
    @color = JTTui.aaxz_basic
  end
  
  def caption=(value)
    @caption = value
    breakwords
    paintcontext do |pc|
      pc.fillrect 0, 0, w, h, ?\s|@color
      pc.move 0,0
      pc.addstra(@caption, JTTui.aaxz_basic)
    end
    JTCur.refresh
    addmessage self, :paint
  end
end

class FLNSlidingTextReader < JTTWList
  def initialize(*args, &block)
    @totalwidth = 1
    super
    @color = JTTui.aaxz_basic
    @color_basic = JTTui.aaxz_basic
    @color_active = JTTui.aaxz_reversed
  end

  def list=(list)
    @list = list
    update
  end
  
  def update
    @totalwidth = 1
    @list.each_index{ |idx|
      cw = self.list_getitemsize(idx)[0]
      @totalwidth = cw if  cw > @totalwidth
    }
    updatescrollers
  end

  def list_getitemsize(idx)
    [@list[idx].length, 1]
  end
  
  def list_gettotalwidth
    @totalwidth
  end

  def list_getlength
    (@list.size if @list) || 0
  end

  def list_drawitem(pc, hilighted, focused, idx)
    super(pc, false, true, idx)
    pc.addstr @list[idx]
  end

  def step_minus
    if @scrolly
      @scrolly.normalizedposition = [@scrolly.normalizedposition - 1, 0].max
    end
    addmessage self, :paint
  end

  def step_plus
    if @scrolly
      @scrolly.normalizedposition = [@scrolly.normalizedposition + 1, @virtualh - @scrollysize].min
    end
    addmessage self, :paint
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
end

class FLNButtonlessEditline < JTTWEditline
  def initialized(*arguments,&block)
    super(*arguments,&block)
    @color = JTTui.aaxz_basic
    @color_active = JTTui.aaxz_important
    @color_active_hi = JTTui.aaxz_reversed
  end
  
  def get_finished(starttext, &block)
    @editor.text = starttext
    @editor.movetoeot
    @finished_callback = Proc.new(&block)
  end

  def keypress(key)
    if 'C-m' == key
      self.enabled = false
      @finished_callback.call(@editor.text) if @finished_callback
      close
    else
      super
    end
  end
end

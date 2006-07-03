require 'observer'

class SelectionModel
  include Observable
  attr_accessor :list, :selected, :total
  
  def list=(values)
    if @list != values
      changed
      @list = values
      notify_observers(values)
    end
  end
  
  def selected=(value)
    if @selected != value
      changed
      @selected = value
      notify_observers(value)
    end
  end
  
  def total=(value)
    if @total != value
      changed
      @total = value
      notify_observers(value)
    end
  end
end

module StringUtils
  # taken from p. 75 of the Pickaxe, 2 ed.
  def StringUtils.mixed_case(name)
    name.gsub(/(\A|\s)\w/) { |first| first.upcase } if name
  end
  
  def StringUtils.justify_attribute_list(list, offset = 4)
    out = ''
    max_width = offset + list.max{|l,r| l[0].length <=> r[0].length}[0].length if list.size > 0
    list.each do |attribute|
      out << (' ' * (max_width - attribute[0].length)) << attribute[0] << ': ' << attribute[1] << "\n"
    end
    out
  end
end
module VR

#  This class is a helper to VR::ListView and VR::TreeView.  When
#  colums are created, this class is used as the renderer because
#  it adds functionality to the Gtk Renderer.
#  
#  When you call ListView#render(model_col) an instance of this class
#  will be returned.  It is a subclass of
#  
#  {Gtk::CellRendererText}[http://ruby-gnome2.sourceforge.jp/hiki.cgi?Gtk%3A%3ACellRendererText]
#  
#  So it has all the functionality of its parent, plus the methods listed here.

  class CellRendererDate < Gtk::CellRendererText
  
  	attr_accessor :date_format, :edited_callback, :model_col, :column, :model_sym

  	def initialize(model_col, column, view, model_sym) # :nodoc:
  		super()
			@model_col = model_col
			@column = column
			@view = view
			@model_sym = model_sym
			@view.model.set_sort_func(@model_col) { |m,x,y| x[@model_col] <=> y[@model_col] }
			@date_format = "%m-%d-%Y"
  		@validate_block = Proc.new { |text, model_sym, row, view| 
				begin
					Date.strptime(text, @date_format)
					true
				rescue
					alert("Unrecognized date format:  " + text)
					false 
				end } 
			@edited_block = nil
      self.signal_connect('edited') do |ren, path, text|
    		next unless iter = @view.model.get_iter(path)
    		if @validate_block.call(text, @model_sym, @view.vr_row(iter), @view)
    			iter[@model_col] = DateTime.strptime(text, @date_format)
  				@edited_callback.call(@model_sym, @view.vr_row(iter)) if @edited_callback
    		end
      end
		end
	end

end

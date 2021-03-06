# 
#  GladeGUI connects your class to a glade form. 
#  It will load a .glade
#  file into memory, enabling your ruby programs to have a GUI interface.
#  
#  GladeGUI works by adding an instance variable, @builder to your class.  The @builder
#  variable is an instance of {Gtk::Builder}[http://ruby-gnome2.sourceforge.jp/hiki.cgi?Gtk%3A%3ABuilder]
#  It holds references to all your windows and widgets.
#  
#  ==Include the GladeGUI interface
#  
#  To use the GladeGUI interface, include this line after your 
#  “class” declaration:
#  
#   include GladeGUI
#  
#  Here is an example of a class that uses GladeGUI:
#  
#   class MyClass
#     include GladeGUI
#   end
#  
#  GladeGUI will load a corresponding 
#  glade file for this class.  It knows which glade file to load by using a naming 
#  convention:
#  
#   /home/me/visualruby/projectname/bin/MyClass.rb 
#  
#  Will load this glade file:
#  
#   /home/me/visualrubyprojectname/bin/glade/MyClass.glade
#  
#  Note: it will use this format: /my/path/glade/<class_name>.glade.
#  In the example, the class and the file have the same name,
#  MyClass.  You should always name your class, script, and glade file
#  the same name (case sensitive).
#  
#  ==@builder holds all your widgets
#  
#  So when you "load" your class's glade file where is it loaded?
#  
#  GladeGUI adds an instance variable, @builder to your class.
#  It loads all the windows and widgets from your glade file into @builder.
#  So, you use @builder to manipulate everything in you class's GUI.
#  @builder is set when you call the show_glade() method, as this code shows:
#  
#   class MyClass
#    
#     include GladeGUI
#     
#     def initialize()
#       puts @builder.to_s  #  => nil
#     end
#     
#     def before_show()
#       puts @builder.to_s   #  => Gtk::Builder
#     end	
#    
#   end
#  
#  After show_glade() is called, you can access any of your form's windows or widgets
#  using the @builder variable: 
#  
#    @builder["window1"].title = "This is the title that appears at the top."
#  
#  
#  Here's another example:  Suppose you have a glade form with a Gtk::Entry box on it named "email."
#  You could set the text that appears in the Gtk::Entry by setting the Gtk::Entry#text property:
#  
#   @builder["email"].text = "harvey@harveyserver.com"
#  
#  Now the email adddess is set with a new value:
# 
#  http://visualruby.net/img/gladegui_simple.jpg
#  
#  ==Auto fill your glade form
#  You can streamline the process of setting-up your forms by
#  auto-filling the widgets from instance variables with the same name.
#
#  When assigning names to widgets in glade, give them names that 
#  correspond to your instance variables. For example, if you want 
#  to edit an email address on the glade form, create an instance 
#  variable named @email in your class. Then, in glade, you 
#  add a Gtk::Entry widget to your form and set its name to 
#  “email”. The advantage of this is that GladeGUI will populate 
#  the “email” widget in glade using the @email variable. so 
#  you don’t need to include the above line of code. (see 
#  set_glade_variables() method.)


module GladeGUI

	attr_accessor :builder

##
#
#  drag_to() will make it so you can drag-n-drop the source_widget onto the target widget.
#  You may pass a reference to a widget object, or a String that gives the name of the
#  widget on your glade form. So, it functions the same as this statement:
#  
#  		widget_source.drag_to(widget_target)
#  
#  It also functions the same as this statement:
#  
#  		@builder["widget_source"].drag_to(@builder["widget_target"])
#  
#  

def set_drag_drop(hash)
	hash.each do |key,val|
		src = key.is_a?(Gtk::Widget) ? key : @builder[key]
		target = @builder[val]
		src.extend(VR::Draggable) unless src.is_a?(VR::Draggable)
		src.add_target_widget(target)
	end
end



##
#  This will Load the glade form.  
#  It will create a Gtk::Builder object from your glade file.
#  The Gtk::Builder object is stored in the instance variable, @builder.
#  You can get a reference to any of the widgets on the glade form by
#  using the @builder object:
#  
#  	widget = @builder["name"]
#  
#  Normally, you should give your widgets names of instance variables: i.e. "MyClass.var"
#  so they can be autoloaded using the set_glade_all() method.
#  
#  You can also pass a reference to a parent class that also includes GladeGUI.
#  Then the child window will run simultaniously with the parent.
#  

	def load_glade()
		caller__FILE__ = my_class_file_path() 
		file_name = File.split(caller__FILE__)[0] + '/glade/' + class_name(self) + ".glade" 
		@builder = Gtk::Builder.new
		@builder << file_name
   @builder.connect_signals{ |handle| method(handle) }
#		parse_signals() should be called after before_show()
	end

	def class_name(obj) # :nodoc:
		/.*\b(\w+)$/.match(obj.class.name)[1]
	end		

	def parse_signals() # :nodoc:
		meths = self.class.instance_methods()
  	meths.each do |meth|
			meth = meth.to_s #bug fix ruby 1.9 gives stmbol
  		glade_name, signal_name = *(meth.split("__"))
			next if (signal_name.to_s == "" or glade_name.to_s == "") #covers nil
			if @builder
  			@builder.objects.each do |obj|
  				next unless obj.respond_to?(:builder_name)
  				if obj.builder_name == glade_name or obj.builder_name =~ /^(?:#{class_name(self)}\.|)#{glade_name}\[\d+\]$/ #arrays
  					obj.signal_connect(signal_name) { |*args| method(meth.to_sym).call(*args) } 
  				end
  			end
  		end
			obj = glade_name == "self" ? self : self.instance_variable_get("@" + glade_name)
			obj ||= eval(glade_name) if respond_to?(glade_name) and method(glade_name.to_sym).arity == 0 # no arguments!
			obj.signal_connect(signal_name) { |*args| method(meth.to_sym).call(*args) } if obj.respond_to?("signal_connect") 
		end
	end

#  This method is the most useful method to populate a glade form.  It will
#  populate from active_record fields and instance variables.  It will simply 
#  call both of these methods:
#  
#   set_glade_active_record()
#   set_glade_variables()
#  
#  So, to set all the values of a form, simply call the set_glade_all() method instead.

	def set_glade_all(obj = self) 
 		set_glade_active_record(obj)
		set_glade_variables(obj)
#		set_glade_hash(obj) if obj.is_a?(Hash) #only needed for Hash subclass. needed?
	end

#  This method is the most useful method to retreive values from a glade form.  It will
#  populate from active_record fields and instance variables.  It will simply 
#  call both of these methods:
#  
#   get_glade_active_record()
#   get_glade_variables()
#  
#  So, to retreive all the values of a form back into your ActiveRecord object and instance variables, simply call the set_glade_all() method instead.

	def get_glade_all(obj = self)
 		get_glade_active_record(obj)
		get_glade_variables(obj)
	end

#  Populates the glade form from the fields of an ActiveRecord object.
#  So instead of having to assign each widget a value:
#  
#  		@builder["ARObject.name"].text = @name
#  		@builder["ARObject.address"].text = @address
#  		@builder["ARObject.email"].text = @eamil
#  		@builder["ARObject.phone"].text = @phone
#  
#  you can write one line of code:
#  
#  	set_glade_active_record()
#  
#  The optional parameter is seldom used because you usually want the
#  glade form to populate from the calling class.  If you passed another object,
#  the form would populate from it.
#  
#  obj - type ActiveRecord::Base
#  

	def set_glade_active_record(obj = self) 
		return if not defined? @attributes
		obj.attributes.each_pair { |key, val| fill_control(class_name(obj) + "." + key, val) }
	end

	def set_glade_hash(hash)
		return unless hash.is_a?(Hash)
		hash.each { |key,val| fill_control( key.to_s, val.to_s) }
	end

#Populates the glade form from the instance variables of the class.
#This works for Gtk:Button, Gtk::Entry, Gtk::Label and Gtk::Checkbutton.
#So instead of having to assign each widget a value:
#
#		@builder["DataObjectGUI.name"].text = @name
#		@builder["DataObjectGUI.address"].text = @address
#		@builder["DataObjectGUI.email"].text = @eamil
#		@builder["DataObjectGUI.phone"].text = @phone
#
#you can write one line of code:
#
#	set_glade_variables()
#
#The optional parameter is seldom used because you usually want the
#glade form to populate from the calling class.  If you passed another object,
#the form would populate from it.
#
#obj - type Object
#


		
	def set_glade_variables(obj = self)
#		set_glade_hash(obj) if obj.is_a?(Hash) 
		obj.instance_variables.each do |name|
			name = name.to_s #ruby 1.9 passes symbol!
			v = obj.instance_variable_get(name)
			x = v.to_s
			if v.class == Array 
				(0..v.size-1).each do |i|
					fill_control(class_name(obj) + "." + name.gsub("@", "") + "[" + i.to_s + "]", v[i] )
				end	
			else
				fill_control(class_name(obj) + "." + name.gsub("@", ""), v)
			end
		end
	end
	


	def fill_control(glade_name, val) # :nodoc:
		control = @builder[glade_name]
		control_name = glade_name.split(".")[1]
		control ||= @builder[control_name] if control_name
		case control
  		when Gtk::Window then control.title = val
  		when Gtk::CheckButton then control.active = val
			when Gtk::TextView then control.buffer.text = val.to_s
  		when Gtk::Entry then control.text = val.to_s
			when Gtk::FontButton then control.font_name = val.to_s
			when Gtk::LinkButton then control.uri = control.label = val.to_s 
  		when Gtk::Label, Gtk::Button then control.label = val.to_s
			when Gtk::Image then control.file = val.to_s 
			when Gtk::SpinButton then control.value = val.to_f
			when Gtk::ProgressBar then control.fraction = val.to_f
			when Gtk::Calendar then control.select_month(val.month, val.year) ; control.select_day(val.day) ; control.mark_day(val.day)
			when Gtk::Adjustment then control.value = val.to_f
			when Gtk::ScrolledWindow, Gtk::Frame, Gtk::VBox, Gtk::HBox then control.add(val)
		end			
	end


#
#	def fill_control(glade_name, val) # :nodoc:
#		return unless glade_name and val
#puts glade_name + val.to_s
#		control = @builder[glade_name]
#puts control.class
#		control_name = glade_name.split(".")[1]
#		control ||= @builder[control_name] unless control_name.nil?
#		return if control.nil?
#		case control.class
#  		when Gtk::Window then control.title = val
#  		when Gtk::CheckButton then control.active = val
#			when Gtk::TextView then control.buffer.text = val.to_s
#  		when Gtk::Entry then control.text = val.to_s
#			when Gtk::FontButton then control.font_name = val.to_s
#			when Gtk::LinkButton then control.uri = control.label = val.to_s 
#  		when Gtk::Label, Gtk::Button then control.label = val.to_s
#			when Gtk::Image then control.file = val.to_s 
#			when Gtk::SpinButton then control.value = val.to_f
#			when Gtk::ProgressBar then control.fraction = val.to_f
#			when Gtk::Calendar then control.select_month(val.month, val.year) ; control.select_day(val.day) ; control.mark_day(val.day)
#			when Gtk::Adjustment then control.value = val.to_f
#			when Gtk::ScrolledWindow, Gtk::Frame, Gtk::Box then control.add(val)
#		end			
#	end
#
#  Populates the instance variables from the glade form.
#  This works for Gtk:Button, Gtk::Entry, Gtk::Label and Gtk::Checkbutton.
#  So instead of having to assign instance variable:
#  
#    @name = @builder["DataObjectGUI.name"].text 
#    @address = @builder["DataObjectGUI.address"].text 
#    @eamil = @builder["DataObjectGUI.email"].text 
#    @phone = @builder["DataObjectGUI.phone"].text 
#    
#  you can write one line of code:
#    
#    get_glade_variables()
#    
#  The optional parameter is seldom used because you usually want the
#  glade form to populate from the calling class.  If you passed another object,
#  the form would populate from it.
#  
#  obj - type Object
#

	def get_glade_variables(obj = self)
		obj.instance_variables.each do |v|
			v = v.to_s  #fix for ruby 1.9 giving symbols
  		control = @builder[class_name(obj) + v.gsub("@", ".")]
  		control ||= @builder[v.gsub("@", "")]
  		case control
				when Gtk::CheckButton then obj.instance_variable_set(v, control.active?)
				when Gtk::Entry then obj.instance_variable_set(v, control.text)
				when Gtk::TextView then obj.instance_variable_set(v, control.buffer.text)
				when Gtk::FontButton then obj.instance_variable_set(v, control.font_name) 
				when Gtk::Label, Gtk::Button then obj.instance_variable_set(v, control.label)
				when Gtk::SpinButton then obj.instance_variable_set(v, control.value)
				when Gtk::Image then obj.instance_variable_set(v, control.file)
				when Gtk::ProgressBar then obj.instance_variable_set(v, control.fraction)
				when Gtk::Calendar then obj.instance_variable_set(v, DateTime.new(*control.date))
				when Gtk::Adjustment then obj.instance_variable_set(v, control.value)
  		end				
		end
	end


	def get_glade_active_record(obj) # :nodoc:
		return if not defined? @attributes
		obj.attributes.each_pair do |key, val|
  		control = @builder[class_name(obj) + "." + key]
  		control ||= @builder[key]
  		case control
				when Gtk::CheckButton then self.send("#{key}=", control.active?)
				when Gtk::Entry then self.send("#{key}=", control.text)
				when Gtk::TextView then self.send("#{key}=", control.buffer.text)
				when Gtk::FontButton then self.send("#{key}=", control.font_name) 
				when Gtk::Label, Gtk::Button then self.send("#{key}=", control.label)
				when Gtk::SpinButton then self.send("#{key}=", control.value)
				when Gtk::Image then self.send("#{key}=", control.file)
				when Gtk::ProgressBar then self.send("#{key}=", control.fraction)
				when Gtk::Calendar then self.send("#{key}=", DateTime.new(*control.date))
				when Gtk::Adjustment then self.send("#{key}=", control.value)
  		end	 
		end
	end



	def self.included(obj)
		temp = caller[0].split(":") #correct for windows  C:\Users\george etc.
		caller_path_to_class_file, = temp[0].size == 1 ? temp[0] + ":" + temp[1] : temp[0] 
		obj.class_eval do
			define_method :my_class_file_path do
				return caller_path_to_class_file
			end
		end
	end


#
#This shows the window and will start the Gtk.main loop (for top level windows.)
#Using show_glade() is better than using Gtk.main and
#Gtk.main.quit because visualruby automatically opens and closes all windows properly.
#
#
	def show_glade(parent = nil)
		load_glade()
		if parent then
				@builder["window1"].transient_for = parent.builder["window1"]
				@builder["window1"].modal = true
		end
		before_show() if respond_to? :before_show
		parse_signals()
		set_glade_all()
		@builder["window1"].show  #show_all can't hide widgets in before_show
		@top_level_window = Gtk.main_level == 0 ? true : false
		Gtk.main if @top_level_window or @builder["window1"].modal?	#need new Gtk.main for blocking!
	end


	def window1__destroy(*args)
		Gtk.main_quit if @top_level_window or @builder["window1"].modal?  
	end

	def active_record_valid?(show_errors = true)
  	get_glade_all
  	if not self.valid?
  		alset(self.errors.full_messages.join("\n\n")) if show_errors
  		self.reload
  		return false
  	end
		return true
	end

end
  
  

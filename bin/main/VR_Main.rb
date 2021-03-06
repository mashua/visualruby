class VR_Main 

	include GladeGUI

	attr_accessor :proj_path, :tabs, :shell, :builder, :file_tree	
	
  def initialize(argv)
		#load global settings
		$VR_ENV_GLOBAL = VR::load_yaml(:class => VR_ENV_GLOBAL, :file_name => VR_ENV_GLOBAL::GLOBAL_SETTINGS_FILE)
#		unless $VR_ENV_GLOBAL = VR_ENV_GLOBAL.load_yaml(VR_ENV_GLOBAL::GLOBAL_SETTINGS_FILE)
#			$VR_ENV_GLOBAL = VR_ENV_GLOBAL.new(VR_ENV_GLOBAL::GLOBAL_SETTINGS_FILE)
#			$VR_ENV_GLOBAL.save_yaml()
#		end
		#try to open right project
		@proj_path = argv[0] ? argv[0] : Dir.pwd
		@proj_path = @proj_path.chomp("/")
		if not project_valid?(@proj_path) 
			@proj_path = $VR_ENV_GLOBAL.default_project if project_valid?($VR_ENV_GLOBAL.default_project)
		end
		@proj_path = ENV["HOME"] unless File.split(@proj_path).length >= 2 and File.directory?(@proj_path)
	end

	def before_show
		@file_tree = VR_File_Tree.new(self, File.expand_path(File.dirname(__FILE__) + "/../../img"))
		@builder["scrolledwindowFileTree"].add(@file_tree) 

		#add document notebook		
    @tabs = VR_Tabs.new(self)  
    @builder["boxTabs"].add(@tabs) 

		#add shell textview
		@shell = VR_TextShell.new(@tabs)
		@builder["scrollShell"].add(@shell) 

		#add local gem tab
		@gem_tree = VR_Local_Gem_Tree.new(self)
		@builder['scrolledLocalGems'].add(@gem_tree) 
		#add remote gem tab
		@remote_gem_tree = VR_Remote_Gem_Tree.new(self)
		@builder["scrolledRemoteGems"].add(@remote_gem_tree)

		if Dir.entries(@proj_path).join == "..." #empty
			VR_Tools.copy_recursively(File.dirname(__FILE__) + "/../../skeleton/project", @proj_path)
		end

		menuInstallExamples__activate if not File.directory?(File.join(ENV["HOME"],"","visualruby", "examples","drag_drop"))
		
		while not project_valid?(@proj_path)
			toolOpenFolder_clicked
		end

		load_project

  end


	def project_valid?(proj_path)
		return false if proj_path.nil? or proj_path == ""
		return false if ENV["HOME"] == proj_path
		return false unless File.directory?(proj_path)
		if Dir.entries(proj_path).join == "..." #empty
			VR_Tools.copy_recursively(File.dirname(__FILE__) + "/../../skeleton/project", proj_path)
			return true
		elsif not File.file?(File.join(proj_path, VR_ENV::SETTINGS_FILE))
			# no parent here because main may not exist
			return alert("No Visual Ruby project file was found in this folder:\n\n<b>" + proj_path +  "</b>\n\nDo you wan to open it anyway?",
					:width =>450, 
					:button_yes => "Yes", :button_no => "No",
					:headline => "Project Not Found")
		end #success!
 		return true
	end


	def load_project() # assumes valid_project? is true
		FileUtils.cd(@proj_path)
		@builder['window1'].title = "VR: " + File.basename(Dir.pwd)
		@builder["labelStatus"].label = Dir.pwd
		@file_tree.root = @proj_path
		@file_tree.refresh()
		@shell.buffer.text = ""
		# if default project invalid, set default
		test_file = File.join($VR_ENV_GLOBAL.default_project, VR_ENV::SETTINGS_FILE)
		unless File.file?(test_file)	
			$VR_ENV_GLOBAL.default_project = @proj_path
			VR::save_yaml($VR_ENV_GLOBAL) 
		end 
		load_state()
	end

	def toolBack_clicked 
		@tabs.back()
	end

	def toolOpenFolder_clicked
		save_state
		return unless @tabs.try_to_save_all(:ask=>true)
		old_path = @proj_path
		OpenProject.new(self).show_glade(self)
		if old_path != @proj_path
 			@tabs.try_to_save_all(:ask => false, :close => true)
			load_project()
		end	
	end

	def notebookTree_changed #file, gem notebook
		case @builder['notebookTree'].page
			when 1 then @gem_tree.refresh() 
			when 2 then @remote_gem_tree.refresh(false) #false = don't force refresh
		end
	end 
	
	def window1_key_press(win, key)
		case x = key.keyval
		 	when 65474 then toolRun_clicked # F5
#			when 115 then toolSave_clicked # Ctrl-S
		end
	end

#	def menuCreateLauncher__activate(*a)
#		VR_Tools.create_desktop_launcher
#	end

	def menuCloseAll__activate(*a)
		@tabs.try_to_save_all(:close=>true) 
	end

	def menuSettings__activate(*a)
		$VR_ENV.show_glade(self)
	end

	def menuGlobalSettings__activate(*a)
		$VR_ENV_GLOBAL.show_glade(self)
		@tabs.update_style_all()
	end

	def menuWWWRubygems__activate(*a)
		VR_Tools.popen("#{$VR_ENV_GLOBAL.browser} https://rubygems.org/users/new")
	end

	def menuSaveAll__activate(*a)
		@tabs.try_to_save_all(:ask=>false) # don't prompt 
	end

	def menuNew__activate(*a)
    @tabs.load_tab()
	end

	def menuSaveAs__activate(*a)
		@tabs.docs[@tabs.page].save_as()
	end

	def toolRefresh_clicked
		case @builder['notebookTree'].page
			when 0 then @file_tree.refresh()
			when 1 then @gem_tree.refresh()
			when 2 then @remote_gem_tree.refresh()
		end
	end

	def toolSave_clicked()  # saves open tab
		@tabs.docs[@tabs.page].try_to_save(false) # false = don't ask
	end	

	def menuNewWindow__activate(*a)
		fn = File.dirname(__FILE__) + "/../../skeleton/document/NewWindow.rb"
		@tabs.load_tab()
		@tabs.set_contents(File.open(fn).read)		
	end

	def menuNewProject__activate(*a)
		save_state
		return unless @tabs.try_to_save_all(:ask=>true)
		old_path = @proj_path
		NewProjectGUI.new(self).show_glade(self)
		if old_path != @proj_path
 			@tabs.try_to_save_all(:ask=>false, :close=>true)
			NewProjectGUI.new(self).show_glade(self)
			load_project()
		end	
	end

	def toolHome__clicked(*a)
		default_project = $VR_ENV_GLOBAL.default_project
		return if default_project == @proj_path	
		if not File.exists?( File.join(default_project, VR_ENV::SETTINGS_FILE))
			alert("Your default home project is invalid:\n\n<b>#{default_project}</b>.\n\nGo to: Tools > Global Settings to set it.", 
					:parent=>self, :headline=>"Invalid Home Project")
			return
		end 
		return unless @tabs.try_to_save_all(:ask=>true, :close=>true)
		@proj_path = default_project
		load_project
	end

	def toolBackUp_clicked
   return unless @tabs.try_to_save_all(:ask=>true)
		VR_Tools.back_up()
  end

	def toolIndent_clicked
		@tabs.docs[@tabs.page].indent($VR_ENV_GLOBAL.tab_spaces)
  end

	def toolUnIndent_clicked
		@tabs.docs[@tabs.page].unindent($VR_ENV_GLOBAL.tab_spaces)
  end

	def toolComment_clicked
		@tabs.docs[@tabs.page].comment()
  end

	def toolUnComment_clicked
		@tabs.docs[@tabs.page].un_comment()
	end

	def toolRun_clicked
   	run_command($VR_ENV.run_command_line)
  end 		

	def run_command(cmd)
    save_state()
    return unless @tabs.try_to_save_all(:ask => false) # false = don't prompt for changes to files
		cur_dir = Dir.pwd
    result = "\n#{cur_dir}$ #{cmd}\n"
    result += `#{cmd} 2>&1`
		FileUtils.cd(cur_dir)
		@shell.hilight_links(result, true)
	end

  def save_state
		return unless $VR_ENV
    $VR_ENV.width, $VR_ENV.height = @builder["window1"].size()
    $VR_ENV.panel_pos = @builder["panelMain"].position
    $VR_ENV.notebook_panel_position = @builder["panelNotebook"].position
    $VR_ENV.open_folders = @file_tree.get_open_folders()
    $VR_ENV.open_files = @tabs.get_open_fn()
    $VR_ENV.current_file = @tabs.docs[@tabs.page].full_path_file
		$VR_ENV.current_line = @tabs.docs[@tabs.page].line_at_cursor()
    VR::save_yaml($VR_ENV)
  end

	def load_state
		$VR_ENV = VR::load_yaml(:class => VR_ENV, :file_name => VR_ENV::SETTINGS_FILE)
#		unless $VR_ENV = VR_ENV.load_yaml(VR_ENV::SETTINGS_FILE) 
#			$VR_ENV = VR_ENV.new(VR_ENV::SETTINGS_FILE)
#			$VR_ENV.save_yaml()
#		end
    @builder["window1"].resize($VR_ENV.width, $VR_ENV.height)
    @tabs.open_file_names($VR_ENV.open_files)
    @tabs.switch_to($VR_ENV.current_file)
		@builder[:window1].show_all
    @file_tree.open_folders($VR_ENV.open_folders)
		#fix this not working:
#		@tabs.show
		@tabs.docs[@tabs.page].jump_to_line($VR_ENV.current_line)
    @builder['panelMain'].set_position($VR_ENV.panel_pos)
		@builder["panelNotebook"].set_position($VR_ENV.notebook_panel_position)
#		@builder[:window1].show_all
	end

	def menuCreateGemspec__activate(*a)
		if file_name = VR_Tools.create_gemspec()
			@tabs.destroy_file_tab(file_name)
  		@tabs.load_tab(file_name)
  		@file_tree.refresh()
		end
	end

	def buttonNext_clicked
		@shell.jump_to()
	end

	def buttonFind_clicked
		str = @builder["entryFind"].text
		str = str.length < 2 ? @tabs.docs[@tabs.page].selected_text() : str
		return if str.length < 2
		text = (@builder["radioOnDisk"].active?) ? @tabs.find_in_all(str) : @tabs.find_in_tabs(str)		
		@shell.hilight_links(text, false)
	end	

	def buttonReplace_clicked
		@tabs.docs[@tabs.page].replace(@builder["entryReplace"].text)
	end

	def entryFind_key_press(me, evt)
		return if evt.keyval != 65293 #enter key
		buttonFind_clicked
	end

	def menuTutorials__activate(*a)
		VR_Tools.popen("#{$VR_ENV_GLOBAL.browser} http://www.visualruby.net")
  end
	
	def menuInstallExamples__activate(*a)
		path = File.join(ENV["HOME"], "", "visualruby", "examples")
		VR_Tools.copy_recursively(File.expand_path(File.join(File.dirname(__FILE__),"","..","..","examples")), path) 
		alert("The example projects are installed in this folder:\n\n<b>#{path}</b>\n\n "+
			"Use your <b>/home/visualruby</b> folder for all your visualruby projects.", 
			:parent => self,	
			:headline => "Installing Example Projects...",
			:width => 500) 	
	end

	# needed so tabs can be saved, called before destroy, must return false to close wndow.
  def window1__delete_event(*args)
		save_state
    return true unless @tabs.try_to_save_all(:ask=>true)
    return false #ok to close
  end

	def menuQuit__activate(*a)   
		@builder["window1"].destroy
	end

end

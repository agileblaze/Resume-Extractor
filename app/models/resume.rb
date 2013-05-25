require 'fileutils'
# ecoding: utf-8

class Resume
  	include MongoMapper::Document
  	attr_accessible :file_name, :file_text

	key :file_name,  String
	key :file_text,  Array
	timestamps!

  	def self.resumes_matching(resp, params)
  		puts "Process started!"

  		# Keyword splitted for multiple key values send with spaces
  		keywords = params[:keyword].split(" ") rescue []

  		if keywords.count > 0
  			# Keywords with regex operator
  			keywords = keywords.collect{|key| /#{key}/}

  			# Matching resumes with all keyword values	
  			resumes = Resume.where(:file_text => { :$all => keywords })

		 	# Url prepared for all resume matching to keywords
		 	resp[:messages] = resumes.collect{|res| resp[:root_url] + "attachments/" + res.file_name}
  		end

  		# Response status set to true which is false as default
  		resp[:status] = true

  		resp
  	end


  	# Following linux packages are used here : pdftotext, docx2txt, catdoc
  	def self.gmail_attachments(resp, params)
  		puts "Process started!"

  		# Authorizes career gmail account
		gmail_user = Gmail.connect(params["email"], params["password"])		

		if gmail_user.logged_in?
			# Loged in successfully - Following messages are for showing logs in front-end
			resp[:messages] << "Connection authorized!"

			# Checks whether email account used earlier to get mails count already fetched
			site_variable = SiteVariable.find_by_email(params["email"])

			# If site_variable exists starting index of mail to be fetched is set to site_variable.mails_count + 1, otherwise 0
			start_no = site_variable.present? ? site_variable.mails_count + 1 : 0

			# End index of mail is set to start index + limit
			end_no = start_no + params["limit"]

			# Read user inbox mails and total count
			emails =  gmail_user.inbox.emails
			total_count = emails.count

			# Using start and end index mails to be processed is taken
			emails =  emails[start_no..end_no] rescue []

			# If value is nil, set as blank array
			emails = [] if emails.nil?

			# Folder created for attachments
			folder = "public/attachments/"			
			FileUtils.mkpath folder

			# Processing mails for attachments
			emails.each_with_index do |email, index|
			    if !email.message.attachments.empty?

			    	# Email have attachments
		   			email.message.attachments.each do |file|		   				
		   				file_type = file.content_type.split(";")[0]

		   				if file_type.include?("application")

			   				resp[:messages] << "Found attachment " + file.filename + "!"

			   				# Token added with file name
			   				file_name = SecureRandom.hex(16) + file.filename

			   				# Removes spaces in attachment name
			   				file_name = file_name.split(" ").join("-")

			   				# attachment saved to folder
						  	File.open(File.join(folder, file_name), "w+b", 0644 ) { |f| f.write file.body.decoded }

						  	file_name_parts = file_name.split(".")
						  	file_extension = file_name_parts[file_name_parts.count - 1]

						  	if ["pdf", "docx", "doc"].include?(file_extension)
						  		resp = Resume.process_selected_file(resp, folder, file_name)	
						  	else if file_type.include?("application/x-gzip")
						  		extract_command = "tar -zxvf " + folder + file_name + " -C "
					  		else if file_type.include?("application/zip")
						  		extract_command = "unzip " + folder + file_name + " -d "
						  	else if file_type.include?("application/rar")
						  		extract_command = "unrar e " + folder + file_name + " "
						  	end
						  	end
						  	end
						  	end

						  	# Extracting zip files
						  	if extract_command
						  		zip_folder = "public/" + SecureRandom.hex(16) + "/"
						  		FileUtils.mkpath zip_folder
						  		extract_command += zip_folder						  		
						  		IO.popen(extract_command)
						  		files_extracted = IO.popen("ls " + zip_folder).to_a
						  		files_extracted.each do |extracted|
						  			file_name_parts = extracted.split(".")
						  			file_extension = file_name_parts[file_name_parts.count - 1]
						  			if ["pdf", "docx", "doc"].include?(file_extension)
						   				file_name = SecureRandom.hex(16) + extracted
						   				file_name = file_name.split(" ").join("-")
						   				command = "cp " + zip_folder + extracted + " " + folder + file_name
						   				IO.popen(command)
						   				resp = Resume.process_selected_file(resp, folder, file_name)
						   			else
						   				resp[:messages] << "Skipped attachment! Not a valid format for resume!"						   				
						  			end
						  		end

						  		# Remove temporary folder
						  		IO.popen("rm -rf " + zip_folder)
						  	end

		                else
		                	resp[:messages] << "Skipped attachment! Not a valid format for resume!"
		                end
					end					
			    else
			    	resp[:messages] << "Skipped mail without attachment!"
			    end
			end

			# Index of last read mail is updated to db for future update
			site_variable = Resume.set_last_updated(params[:email], emails.count)

			# Checks whether all mails read, ie, up to date or not
			resp[:finished] = emails.count == 0 || start_no > total_count ? true : false
			if resp[:finished]
				resp[:percentage] = 100
				resp[:messages] << "Up to date!"
				resp[:messages] << "Total " + site_variable.mails_count.to_s + " mails loaded yet!"
			else
				# Percentage of processing set using count of mails read yet, inbox mails count
				percentage = (site_variable.mails_count.to_f/total_count)*100
				resp[:percentage] = percentage
			end

			resp[:start] = start_no
			resp[:end] = end_no

			# Response status set to true which is false as default
			resp[:status] = true

		else
			# Account failed to authorize
			resp[:percentage] = 100
			resp[:messages] << "Failed to authorize! Please make sure with email & password!"
		end

		resp
  	end



	# Updates last updated mail index for each mail account  
	def self.set_last_updated(email, count)
		site_variable = SiteVariable.find_by_email(email)
		if site_variable
			count = site_variable.mails_count + count
			site_variable.update_attributes(:mails_count => count)
		else
			site_variable = SiteVariable.new(:email => email, :mails_count => count)
			site_variable.save
		end
		site_variable
	end


	# Read file contents
	def self.read_text_lines(filepath)
	 	# Command to read file
  		command = "catdoc " + filepath

		# resume_text initialized, since we have += with this while reding text from files 
	  	resume_text = ""
	  	textlines = IO.popen(command).readlines
		# textlines.each do |line|
		# 	resume_text +=  " " + line
		# end
		# resume_text
		textlines
	end


	def self.process_selected_file(resp, folder, file_name)
	  	if file_name.include?(".pdf")
	  		# If file is pdf, pdftotext is used to create text file
	  		command = "pdftotext " + folder + file_name
	  		IO.popen(command)

	  		# Small delay added to get the text file saved before reading with catdoc
	  		sleep(5)

	  		# To read from text file created, .pdf is replaced with .txt
	  		resume_text = Resume.read_text_lines(folder + file_name.gsub(".pdf", ".txt"))

	  	else if file_name.include?(".doc")
	  		# To read from doc file
	  		resume_text = Resume.read_text_lines(folder + file_name)

		else if file_name.include?(".docx")  #docx file format is not identifiable by file command
			command = "docx2txt.pl " + folder + file_name
	  		IO.popen(command)

	  		# Small delay added to get the text file saved before reading with catdoc
	  		sleep(5)

	  		# To read from text file created, .xlsx is replaced with .txt
	  		resume_text = Resume.read_text_lines(folder + file_name.gsub(".docx", ".txt"))

		else
			resp[:messages] << "Skipped attachment! Not a valid format for resume!"
	  	end
	  	end
	  	end

	  	if resume_text.present? && resume_text != ""
		  	# File name and text saved to model Resume. 
		  	# Using this file name download url can be prepared when searching for particular resume
    		Resume.create(:file_name => file_name, :file_text => resume_text)
    		resp[:messages] << "Saved attachment " + file_name + "!"
    	else
    		resp[:messages] << "Failed to save attachment " + file_name + "!"
    	end

	  	resp
	end





end

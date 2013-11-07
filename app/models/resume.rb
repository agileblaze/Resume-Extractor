require 'fileutils'
require 'shellwords'
# ecoding: utf-8

class Resume
  	include MongoMapper::Document
  	attr_accessible :file_name, :file_text, :file_date, :file_email, :file_original

  	key :file_original, String
  	key :file_email,  String
	key :file_name,  String
	key :file_date,  Date
	key :file_text,  Array
	timestamps!

  	def self.resumes_matching(resp, params)
  		puts "Process started!"

  		# Keyword splitted for multiple key values send with spaces
  		keywords = params[:keyword].split(" ") rescue []

  		puts "Keywords : " + keywords.to_s

  		if keywords.count > 0
  			# Keywords with regex operator
  			keywords = keywords.collect{|key| /#{key}/}

  			# Matching resumes with all keyword values	
  			resumes = Resume.where(:file_text => { :$all => keywords }).order("created_at desc")

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
			current_index = site_variable.present? ? site_variable.mails_count : 0

			# Read user inbox mails and total count
			emails =  gmail_user.inbox.emails
			emails = [] if emails.nil?

			# Folder created for attachments
			folder = "public/attachments/"
			FileUtils.mkpath folder

			# Processing mails for attachments
			emails.each_with_index do |email, index|
				puts "-----------------------------------------"
				puts "Mail index : " + index.to_s

				if email.uid.to_i > current_index
				    if !email.message.attachments.empty?
				    	# Email have attachments
				    	email_date = Date.parse(email.date)
			   			email.message.attachments.each do |file|
			   				puts "File name: " + file.filename

			   				file_type = file.content_type.split(";")[0]
			   				if file_type.include?("application")
				   				resp[:messages] << "Found attachment " + file.filename + "!"
				   				file_original = file.filename

				   				# Token added with file name
				   				file_name = SecureRandom.hex(16)
				   				file_name_parts = file.filename.split(".")
							  	file_extension = file_name_parts[file_name_parts.count - 1]
								file_name += ("." + file_extension) if file_extension.present?

				   				# Attachment saved to folder
							  	File.open(File.join(folder, file_name), "w+b", 0644 ) { |f| f.write file.body.decoded }

							  	puts "File extension : " + file_extension

							  	if ["pdf", "docx", "doc"].include?(file_extension)
							  		resp = Resume.process_selected_file(resp, folder, file_name, email_date, file_original)	
							  	elsif file_type.include?("application/x-gzip")
							  		puts "application/x-gzip"
							  		extract_command = "tar -zxvf " + folder + file_name + " -C "
						  		elsif file_type.include?("application/zip")
						  			puts "application/zip"
							  		extract_command = "unzip " + folder + file_name + " -d "
							  	elsif file_type.include?("application/rar")
							  		puts "application/rar"
							  		extract_command = "unrar e " + folder + file_name + " "
							  	end

							  	# Extracting zip files
							  	if extract_command
							  		puts "Extracting files......."

							  		zip_folder = "public/extracted/" + SecureRandom.hex(16) + "/"
							  		FileUtils.mkpath zip_folder
							  		extract_command += zip_folder
							  		sleep(5)

							  		puts "Extracting command : " + extract_command

							  		IO.popen(extract_command)
							  		sleep(20)
							  		files_extracted = IO.popen("ls " + zip_folder).to_a
							  		sleep(5)

							  		puts "Files are......"

							  		files_extracted.each do |extracted|
							  			extracted = extracted.strip
							  			file_name_parts = extracted.split(".")
							  			file_extension = file_name_parts[file_name_parts.count - 1].strip
							  			file_original = extracted.split("/")
							  			file_original = file_original[file_original.count - 1]

							  			puts "Extracted extension : " + file_extension

							  			if ["pdf", "docx", "doc"].include?(file_extension)
							   				file_name = SecureRandom.hex(16) + "." + file_extension
							   				copy_command = "cp " + zip_folder + Shellwords.escape(extracted) + " " + folder + file_name

							   				puts "Copying file : " + copy_command

							   				IO.popen(copy_command)
							   				sleep(5)
							   				resp = Resume.process_selected_file(resp, folder, file_name, email_date, file_original)
							   			else
							   				resp[:messages] << "Skipped attachment! Not a valid format for resume!"
							  			end
							  		end
							  		# Remove temporary folder
							  		# IO.popen("rm -rf " + zip_folder)
							  	end
			                else
			                	resp[:messages] << "Skipped attachment! Not a valid format for resume!"
			                end
						end
				    else
				    	resp[:messages] << "Skipped mail without attachment!"
				    end
				    site_variable = Resume.set_last_updated(params[:email], email.uid)
				end
			end

			resp[:finished] = true
			resp[:percentage] = 100
			resp[:messages] << "Up to date!"
			resp[:messages] << "Total " + site_variable.mails_count.to_s + " mails loaded yet!"
			resp[:status] = true
		else
			# Account failed to authorize
			resp[:percentage] = 100
			resp[:messages] << "Failed to authorize! Please make sure with email & password!"
		end
		resp
  	end


	# Updates last updated mail id for each mail account
	def self.set_last_updated(email, uid)
		site_variable = SiteVariable.find_by_email(email)
		if site_variable
			site_variable.update_attributes(:mails_count => uid)
		else
			site_variable = SiteVariable.new(:email => email, :mails_count => uid)
			site_variable.save
		end
		site_variable
	end


	# Read file contents
	def self.read_text_lines(filepath)
	 	# Command to read file
  		read_command = "catdoc " + filepath
	  	resume_text = ""
	  	textlines = IO.popen(read_command).readlines
		textlines
	end


	def self.process_selected_file(resp, folder, file_name, file_date, file_original)
		puts "Processing " + file_name

	  	if file_name.include?(".pdf")
	  		puts "Reading pdf"
	  		# If file is pdf, pdftotext is used to create text file
	  		command = "pdftotext " + folder + file_name
	  		IO.popen(command)

	  		# Small delay added to get the text file saved before reading with catdoc
	  		sleep(5)

	  		# To read from text file created, .pdf is replaced with .txt
	  		resume_text = Resume.read_text_lines(folder + file_name.gsub(".pdf", ".txt"))

		else if file_name.include?(".docx")  #docx file format is not identifiable by file command
			puts "Reading docx"

			# If file is docx, docx2txt is used to create text file
			command = "docx2txt.pl " + folder + file_name
			IO.popen(command)

	  		# Small delay added to get the text file saved before reading with catdoc
	  		sleep(5)

	  		# To read from text file created, .xlsx is replaced with .txt
	  		resume_text = Resume.read_text_lines(folder + file_name.gsub(".docx", ".txt"))

	  	else if file_name.include?(".doc")
	  		puts "Reading doc"
	  		# To read from doc file
	  		resume_text = Resume.read_text_lines(folder + file_name)

		else
			resp[:messages] << "Skipped attachment! Not a valid format for resume!"
	  	end
	  	end
	  	end

	  	if resume_text.present?
	  		emails = []
	  		resume_text = resume_text.collect{|text| email = text.match(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i); emails << email.to_s.strip unless email.nil?; text.downcase rescue "" }
	  		file_email = emails.join(", ")
		  	# File name and text saved to model Resume.
    		Resume.create(:file_name => file_name, :file_text => resume_text, :file_date => file_date, :file_email => file_email) rescue false
    		resp[:messages] << "Saved attachment " + file_name + "!"
    	else
    		resp[:messages] << "Failed to save attachment " + file_name + "!"
    	end

	  	resp
	end





end

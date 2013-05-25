require 'rubygems'
require 'highline/import'
require 'gmail'
require 'fileutils'

class Extractor

        def application
            printf "\n"  
            case(ARGV[0])
                when "attachments"
                    email = ARGV[1]
                    puts "Email : " + email  
                    printf "\n"  
                    password = get_password()

                    gmail = Gmail.connect(email, password)
                    if gmail.logged_in?
                        puts "Success!"
                        printf "\n"

                        FileUtils.mkpath 'attachments'
                        puts "Folder 'attachments' created!"
                        printf "\n"

                        folder = "attachments/"

                        gmail.inbox.emails.each_with_index do |email, index|                                                        
                            if !email.message.attachments.empty?                                                             
                                attachment = email.attachments.first
                                puts "Saving attachment " + attachment.filename 
                                printf "\n"                           
                                File.open(folder+attachment.filename,"w+") { |local_file| local_file << attachment.decoded }                               
                            end
                        end

                        puts "Done!"

                    else
                        puts "Failed to connect with Gmail! Please make sure with email & password!"                    
                    end
                     
                when "extract"

                else
                    puts "Invalid mode!"
                    printf "\n"
                    puts "Please use any of following method:"
                    printf "\n"
                    puts "To download attachments : ruby extractor.rb attachments EMAIL_ID"
                    printf "\n"                        
            end
        end

        def extract
                #puts "Enter filename :"
                # path = gets.chomp
                # command = "catdoc " + path
                
                # text = IO.popen(command).readlines  
                # puts text        
        end

        def get_password(prompt="Enter Password :")
            ask(prompt) {|q| q.echo = false}
        end 
end

ext = Extractor.new  
ext.application 


#sudo apt-get install catdoc
#gem install gmail

class SiteVariable
  	include MongoMapper::Document
  	attr_accessible :email, :mails_count

	key :email,  String
	key :mails_count,   Integer
	timestamps!
end

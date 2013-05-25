class ApplicationController < ActionController::Base
  	protect_from_forgery

  	before_filter :response_hash

  	def response_hash
		@resp = {:root_url => root_url, :status => false, :messages => []}
	end
end

// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require_tree .
//= require mustache
//= require bootstrap


// Ajax API call initialization with callback function
function initialize_api_call(api_params, callback, callback_params){
	if(!api_params["params"]) api_params["params"] = {};
	if(!callback_params) callback_params = {};

	$.ajax({
		  url : api_params["url"], type : api_params["type"], data : api_params["params"],
		  success : function(response)
		  {
		  	if(callback && callback != "")
		  		window[callback](response, callback_params, api_params);
		  	
		  },
		  error : function()
		  {
		  	alert("Process failed!");
		  	$("#gmail_loading").hide();
		  	$("#resume_loading").hide();
		  }
	});
}

function authorize_gmail(){
	$("#mail_attchments").html("");
	$("#mail_attchments_per").attr("style", "width:0%;");	
	get_gmail_attachments();
}


function get_gmail_attachments(recursion){
	$("#gmail_loading").show();
	if(!recursion) recursion = false;
	initialize_api_call({"url": "/get_email_attachments", "type": "GET", 
		"params": {"recursion": recursion, "email" : $("#career_email").val(), "password" : $("#career_password").val()}}, 
		"callback_for_templates", {"mode": "gmail"});
}

function callback_for_templates(response, callback_params, api_params){
	switch(callback_params["mode"]){
		case "gmail": 	var html = $.trim(Mustache.render($(".messge-box-template").html(), response["messages"]));	
					   	$("#mail_attchments").append(html);	
   					  	$("#mail_attchments_per").attr("style", "width:"+response["percentage"]+"%;");	
						if(response["status"] == true && response["finished"] == false){							
						   	get_gmail_attachments(true);
						}
						else
							$("#gmail_loading").hide();
							
						break;

		case "resume": 	if(response["messages"].length == 0)
					   		var html = $.trim(Mustache.render($(".resume-box-template").html(), ["Nothing found!"]));
					   	else
					   		var html = $.trim(Mustache.render($(".resume-box-template").html(), response["messages"]));
	
					   	$("#resume_files").append(html);
					   	$("#resume_loading").hide();
					   	break;		

		default: break;
	}	
}


function find_resume(){
	$("#resume_files").html("");
	$("#resume_loading").show();
	initialize_api_call({"url": "/resumes_matching/"+$("#keyword").val(), "type": "GET", 
		"params": {}}, "callback_for_templates", {"mode": "resume"});
}


$(document).ready(function(){		

});

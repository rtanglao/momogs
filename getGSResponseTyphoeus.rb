require 'rubygems'
require 'typhoeus'
GS_USER = ENV["GS_USER"]
raise(StandardError,"Set GS user in  ENV: 'GS_USER'") if !GS_USER
GS_PASSWORD = ENV["GS_PASSWORD"]
raise(StandardError,"Set Mongo user in  ENV: 'GS_PASSWORD'") if !GS_PASSWORD

def getResponse(url, params)
  url = "https://api.getsatisfaction.com/" + url
  result = Typhoeus::Request.get(url,
                                 :username => GS_USER, :password => GS_PASSWORD, 
                                 :params => {:format => :json, :params => params })
  return JSON.parse(result.body)
end

def getURLResponse(url, params)
  result = Typhoeus::Request.get(url,
                                 :username => GS_USER, :password => GS_PASSWORD, 
                                 :params => {:format => :json, :params => params })
  return JSON.parse(result.body)
end

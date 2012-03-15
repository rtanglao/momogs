require 'rubygems'
require 'pp'
require 'nestful'

def getResponse(url, params)
  url = "https://api.getsatisfaction.com/" + url
  return Nestful.get url, :format => :json, :params => params
end


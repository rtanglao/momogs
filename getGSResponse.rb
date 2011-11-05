require 'rubygems'
require 'pp'
require 'nestful'

def getResponse(url, params)
  url = "http://api.getsatisfaction.com/" + url
  try1 = true
  begin
    resp = Nestful.get url, :format => :json, :params => params
  rescue Nestful::TimeoutError
    if try1
      $stderr.printf("retrying after HTTP GET Timeout EXCEPTION, url:%s\n",url)
      sleep(1)
      try1 = false
      retry
    else
      $stderr.printf("2nd HTTP GET Failed with a Timeout EXCEPTION, url:%s TERMINATING\n",url)
      raise
    end
  end
  return resp
end


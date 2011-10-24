require 'rubygems'
require 'json'
require 'net/http'
require 'pp'

def getResponse(url)

  http = Net::HTTP.new("api.getsatisfaction.com",80)

  url = "/" + url 

  try1 = true

  begin
    resp, data = http.get(url, nil)
  rescue Timeout::Error => e
    if try1
      $stderr.printf("retrying after HTTP GET Timeout EXCEPTION, url:%s\n",url)
      try1 = false
      retry
    else
      $stderr.printf("2nd HTTP GET Failed with a Timeout EXCEPTION, url:%s TERMINATING\n",url)
      raise
    end
  end
   
  if resp.code != "200"
    printf(STDERR, "getResponse Parser Error: #%d from:%s\n", resp.code, url)
    raise JSON::ParserError    # this is a kludge, should raise a proper exception!!!!!
    return ""
  end

  result = JSON.parse(data)
  return result
end


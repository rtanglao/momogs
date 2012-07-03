#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'time'
require 'date'
require 'mongo'
require 'AlchemyAPI.rb'
require 'pp'

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in  ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in  ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db("gs")
raise(StandardError, "Couldn't authenticate, exiting") if !db.authenticate(MONGO_USER, MONGO_PASSWORD)

topicsColl = db.collection("topics")

# Create an AlchemyAPI object.
alchemyObj = AlchemyAPI.new()

# Load the API key from disk.
alchemyObj.loadAPIKey("api_key.txt")

url = id = ARGV[0]
# Get sentiment for a web URL.
# result = alchemyObj.URLGetTextSentiment(url);
# puts result

# # Retrieve targeted sentiment
# result = alchemyObj.URLGetTargetedSentiment(url, "Walmart", AlchemyAPI::OutputMode::XML, tsparamObj);
#result = alchemyObj.URLGetRankedKeywords(url, AlchemyAPI::OutputMode::JSON, kparamObj)
# puts result

# Create a parameters object.
kparamObj = AlchemyAPI_KeywordParams.new()

# Enable keyword-targeted sentiment.
kparamObj.setSentiment(1)

# Retrieve keywords with keyword-targeted sentiment.
result = alchemyObj.URLGetRankedKeywords(url, AlchemyAPI::OutputMode::JSON, kparamObj)
pp result


 



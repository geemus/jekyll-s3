require 'rubygems'
require 'fog'
require 'yaml'

module Jekyll
  module S3
  end
end

%w{errors uploader cli}.each do |file|
  require File.dirname(__FILE__) + "/jekyll-s3/#{file}"
end

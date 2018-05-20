class User < ActiveRecord::Base
  belongs_to :team

  attr_encrypted :token, key: ENV['SLACK_ACCESS_TOKEN_KEY']
end
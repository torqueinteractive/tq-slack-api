class User < ActiveRecord::Base
  belongs_to :team

  # attr_encrypted :access_token, key: ENV['SLACK_ACCESS_TOKEN_KEY']
end
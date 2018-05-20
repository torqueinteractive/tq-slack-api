class Api < ActiveRecord::Base

  private

  def self.slack_api_request(type: "enroll", **args)
    case type
      # enroll is a bit of an edge case, so we'll just return right from within
    when "enroll"
      slack_request_params = {
        client_id: ENV["SLACK_CLIENT_ID"],
        scope: args[:scope],
        redirect_uri: api_success_path
      }
      uri = URI.parse("https://slack.com/oauth/authorize")
      uri.query = URI.encode_www_form(slack_request_params)
      return uri.to_s
    when "complete_oath"
      slack_request_params = {
        client_id: ENV["SLACK_CLIENT_ID"],
        client_secret: ENV["SLACK_CLIENT_SECRET"],
        code: params[:code],
        redirect_uri: api_success_path
      }
    when "list_files"
      slack_request_params = {
        token: args[:token],
        count: args[:count],
        user: args[:user]
      }
    end

    uri = URI.parse(args[:endpoint])
    uri.query = URI.encode_www_form(slack_request_params)
    response = Net::HTTP.get_response(uri)

    return response
  end

end
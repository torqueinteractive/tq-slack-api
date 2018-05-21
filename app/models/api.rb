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
      endpoint = "https://slack.com/api/oauth.access"
    when "list_files"
      slack_request_params = {
        token: args[:token],
        ts_to: args[:ts_to] || "now",
        count: args[:count],
        user: args[:user]
      }
      endpoint = "https://slack.com/api/files.list"
    when "delete_files"
      slack_request_params = {
        token: args[:token],
        file: args[:file]
      }
      endpoint = "https://slack.com/api/files.delete"
    end

    endpoint = args[:endpoint] || endpoint

    uri = URI.parse(endpoint)
    uri.query = URI.encode_www_form(slack_request_params)
    response = Net::HTTP.get_response(uri)

    return response
  end

end
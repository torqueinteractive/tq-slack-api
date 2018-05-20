class Api < ActiveRecord::Base

  private

  def self.slack_api_request(type: "request_access", *args)
    case type
    when "request_access"
      logger.warn "requesting auth access"
      slack_request_params = {
        client_id: ENV["SLACK_CLIENT_ID"],
        scope: "files:read files:write:user",
        redirect_uri: "#{request.base_url}/api/success"
      }
    when "list_files"
      logger.warn "doing the list_files one"
      slack_request_params = {
        token: token,
        count: count,
        user: user
      }
    end

    uri = URI.parse(endpoint)
    uri.query = URI.encode_www_form(slack_request_params)
    response = Net::HTTP.get_response(uri)

    return response
  end

end
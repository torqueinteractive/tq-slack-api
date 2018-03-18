class DestroyFilesJob < ApplicationJob
  include HTTParty
  queue_as :default

  def perform(user_access_token, slack_user_id, response_url, age_to_start)
    if age_to_start == "0"
      age_to_start = 0
    elsif age_to_start !~ /\D/
      age_to_start = age_to_start.to_i
    else
      age_to_start = 20
    end

    computed_age_to_start = (Time.now - age_to_start * 24 * 60 * 60).to_i
    params = {
      token: user_access_token,
      ts_to: computed_age_to_start,
      count: 1000,
      user: slack_user_id
    }
    uri = URI.parse("https://slack.com/api/files.list")
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri)
    files = JSON.parse(response.body)["files"]

    unless files.empty?
      file_ids = files.map { |f| f['id'] }
      file_ids.each do |file_id|
        params = {
          token: user_access_token,
          file: file_id
        }
        uri = URI.parse('https://slack.com/api/files.delete')
        uri.query = URI.encode_www_form(params)
        response = Net::HTTP.get_response(uri)
      end

      HTTParty.post(response_url,
        body: {
          text: "Finished - you're all set! We deleted #{files.count} files."
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    else
      HTTParty.post(response_url,
        body: {
          text: "It doesn't look like you have any files older than 20 days - nice job!"
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end
  end

end

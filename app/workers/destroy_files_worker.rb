class DestroyFilesWorker
  include Sidekiq::Worker

  def perform(user_access_token, slack_user_id, response_url, age_to_start)
    if age_to_start == "0"
      age_to_start = 0
    elsif age_to_start !~ /\D/
      age_to_start = age_to_start.to_i
    else
      age_to_start = 20
    end

    result_message = "No file found that's older than #{age_to_start} days!"

    computed_age_to_start = (Time.now - age_to_start * 24 * 60 * 60).to_i

    response = Api.slack_api_request(
                 type: "list_files",
                 token: user_access_token,
                 ts_to: computed_age_to_start,
                 count: 1000,
                 user: slack_user_id
               )

    files = JSON.parse(response.body)["files"]

    unless files.empty?
      file_ids = files.map { |f| f['id'] }
      file_ids.each do |file_id|
        Api.slack_api_request(
                     type: "delete_files",
                     token: user_access_token,
                     file: file_id
                   )
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
          text: result_message
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end
  end

end

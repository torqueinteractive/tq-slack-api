class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token
  require "net/http"
  require "json"
  require "uri"

  def index
    @greeting = "Slack API For File Management"
  end

  def enroll
    params = {
      client_id: ENV["SLACK_CLIENT_ID"],
      scope: "files:read files:write:user",
      redirect_uri: "#{request.base_url}/api/success"
    }
    uri = URI.parse("https://slack.com/oauth/authorize")
    uri.query = URI.encode_www_form(params)
    redirect_to uri.to_s
  end

  def success
    @params = params

    unless @params[:access_token].blank?
      User.find_or_create_by(
        access_token: @params[:access_token],
        slack_user_id: @params[:user_id],
        slack_team_id: @params[:team_id],
        slack_user_name: @params[:user_name]
      )
    end

    unless @params["code"].blank?
      params = {
        client_id: ENV["SLACK_CLIENT_ID"],
        client_secret: ENV["SLACK_CLIENT_SECRET"],
        code: @params[:code],
        redirect_uri: "#{request.base_url}/api/success"
      }
      uri = URI.parse("https://slack.com/api/oauth.access")
      uri.query = URI.encode_www_form(params)
      response = Net::HTTP.get_response(uri)

      if JSON.parse(response.body)["access_token"].blank? || JSON.parse(response.body)["user_id"].blank? || JSON.parse(response.body)["team_id"].blank?
        @message = "We couldn't authorize you. Ask bowman about it."
        @it_worked = false
      else
        @message = "Success!"
        @it_worked = true
        User.find_or_create_by(
          access_token: JSON.parse(response.body)["access_token"],
          slack_user_id: JSON.parse(response.body)["user_id"],
          slack_team_id: JSON.parse(response.body)["team_id"],
          slack_user_name: JSON.parse(response.body)["user_name"]
        )
      end
    end
  end

  def get_file_count
    @params = params

    if @params["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = User.find_by(slack_user_id: @params["user_id"], slack_team_id: @params["team_id"])

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        params = {
          token: user.access_token,
          count: 1000,
          user: user.slack_user_id
        }
        uri = URI.parse("https://slack.com/api/files.list")
        uri.query = URI.encode_www_form(params)
        response = Net::HTTP.get_response(uri)
        @total_storage_usage = 0
        files = JSON.parse(response.body)["files"]
        files.each do |file|
          @total_storage_usage += file["size"]
        end

        @total_storage_usage = @total_storage_usage.to_f / 1048576

        render json: {
          text: "*Hello, #{@params['user_name']}.*\nYou've used *#{@total_storage_usage.round(2)} MB* of storage for *#{files.count} files*. That's *#{((@total_storage_usage/5000)*100).round(2)}%* of our capacity."
        }
      end
    else
      render json: {
        message: "You are not authorized to make this request :/"
      }, status: 401
    end
  end

  def destroy_files
    @params = params

    if @params["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = User.find_by(slack_user_id: @params["user_id"], slack_team_id: @params["team_id"])

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        render json: {
          "text": "This will remove files you've shared that are older than 20 days. Are you sure?",
          "attachments": [
            {
              "fallback": "Confirm delete",
              "callback_id": "confirm_delete",
              "color": "#3AA3E3",
              "attachment_type": "default",
              "actions": [
                {
                    "name": "confirm_delete",
                    "text": "Delete Files",
                    "type": "button",
                    "style": "primary",
                    "value": "yes"
                },
                {
                    "name": "confirm_delete",
                    "text": "Cancel",
                    "type": "button",
                    "style": "danger",
                    "value": "no"
                }
              ]
            }
          ]
        }
      end
    else
      render json: {
        message: "You are not authorized to make this request :/"
      }, status: 401
    end
  end

  def manage_interactions
    @params = params
    @params = JSON.parse(@params.as_json.first.last).as_json

    if @params["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = User.find_by(slack_user_id: @params["user"]["id"], slack_team_id: @params["team"]["id"])

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        case @params["callback_id"]
        when "confirm_delete"
          if @params["actions"][0]["value"] == "yes"
            logger.warn @params

            if @params["text"].blank?
              age_to_start = 20
            else
              logger.warn @params["text"]
              age_to_start = @params["text"]
            end
            DestroyFilesWorker.perform_async(user.access_token, user.slack_user_id, @params["response_url"].to_s, age_to_start)
            render json: {
              text: "OK, we're working on it!"
            }, status: :ok
          elsif @params["actions"][0]["value"] == "no"
            render json: {
              text: "Request has been cancelled."
            }, status: :ok
          end
        end
      end
    else
      render json: {
        message: "You are not authorized to make this request :/"
      }, status: 401
    end
  end

end

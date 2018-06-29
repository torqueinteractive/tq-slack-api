class ApiController < ApplicationController
  include Api

  skip_before_action :verify_authenticity_token

  def index
  end

  def enroll
    slack_enroll_url = slack_api_request(
                         type: "enroll",
                         scope: "files:read files:write:user"
                       )
    redirect_to slack_enroll_url
  end

  def success
    unless params["code"].blank?
      response = slack_api_request(
                   type: "complete_oath",
                   code: params[:code]
                 )

      if response.code == "200"
        json_response = JSON.parse(response.body)

        if json_response["access_token"].blank? || json_response["user_id"].blank? || json_response["team_id"].blank?
          @message = "We couldn't authorize you. Ask Bowman about it."
          @it_worked = false
        else
          @message = "Success!"
          @it_worked = true

          team = Team.find_or_create_by(
            name: json_response["team_name"],
            slack_team_id: json_response["team_id"]
          )

          user_exists_for_team = team.users.find_by(slack_user_id: json_response["user_id"])

          if user_exists_for_team.present?
            puts "User has ID of #{user_exists_for_team.id}"
            puts "access token: #{json_response["access_token"]}"
            user_exists_for_team.update_attributes(token: json_response["access_token"])
            render json: {
              text: "It looks like you should already be authorized. Ask bowman about it if it still is having problems."
            }
          else
            team.users.create(
              token: json_response["access_token"],
              slack_user_id: json_response["user_id"],
              user_name: json_response["user_name"]
            )
          end
        end
      else
        render json: {
          text: "Couldn't get the correct response from Slack. Ask Bowman or try again."
        }
      end
    else
      render json: {
        text: "Couldn't get the correct response from Slack. Ask Bowman or try again."
      }
    end
  end

  def get_file_count
    if params["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = Team.find_by(slack_team_id: params["team_id"]).users.find_by(slack_user_id: params["user_id"])

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask Bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        response = slack_api_request(
                     type: "list_files",
                     token: user.token,
                     count: 1000,
                     user: user.slack_user_id
                   )

        if response.code == "200"
          # the final total storage is based on Slack's free plan max size - 5GB
          total_storage_usage = 0
          files = JSON.parse(response.body)["files"]
          if files.present?
            files.each do |file|
              total_storage_usage += file["size"]
            end
            total_storage_usage = total_storage_usage.to_f / 1048576

            # this response includes their user name, so let's make sure we have it and it's up to date
            user.update_attributes(user_name: params['user_name'])

            render json: {
              text: "*Hello, #{params['user_name']}.*\nYou've used *#{total_storage_usage.round(2)} MB* of storage for *#{files.count} files*. That's *#{((total_storage_usage/5000)*100).round(2)}%* of our capacity."
            }
          else
            render json: {
              text: "Couldn't get the correct response from Slack. Ask Bowman or try again."
            }
          end
        else
          render json: {
            text: "Couldn't get the correct response from Slack. Ask Bowman or try again."
          }
        end
      end
    else
      render json: {
        message: "You are not authorized to make this request :/"
      }, status: 401
    end
  end

  def destroy_files
    if params["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = Team.find_by(slack_team_id: params["team_id"]).users.find_by(slack_user_id: params["user_id"])

      if params["text"].blank?
        age_to_start = 20
      else
        age_to_start = params["text"]
      end

      if age_to_start == "0"
        age_to_start = 0
      elsif age_to_start !~ /\D/
        age_to_start = age_to_start.to_i
      else
        age_to_start = 20
      end

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask Bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        render json: {
          "text": "This will remove files you've shared that are older than #{age_to_start.to_i} days. Are you sure?",
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
                    "value": age_to_start
                }, {
                    "name": "refuse_delete",
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
    ui_response = JSON.parse(params['payload'])

    if ui_response["token"] == ENV["SLACK_VERIFICATION_TOKEN"]
      user = Team.find_by(slack_team_id: ui_response["team"]["id"]).users.find_by(slack_user_id: ui_response["user"]["id"])

      if user.blank?
        render json: {
          text: "It doesn't look like you've authorized this app for use yet. Ask Bowman about it or just go to https://slack-api.rebootcreate.com/api/enroll and sign in to authorize."
        }
      else
        case ui_response["callback_id"]
        when "confirm_delete"
          if ui_response["actions"][0]["name"] == "confirm_delete"
            DestroyFilesWorker.perform_async(user.token, user.slack_user_id, ui_response["response_url"].to_s, ui_response["actions"][0]["value"])
            render json: {
              text: "OK, we're working on it!"
            }, status: :ok
          else
            render json: {
              text: "OK, request cancelled!"
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

  def litmus_response
    mg_client = Mailgun::Client.new ENV["MAILGUN_API_KEY"]

    message_params =  { from:    "jonathanrbowman@me.com",
                        to:      "jonathan.bowman@ttigroupna.com, Dave.Breeze@ttigroupna.com, marc.ludena@ttigroupna.com, matt.bainton@ttigroupna.com",
                        subject: "AUTO FORWARDED MESSAGE",
                        text:    "Hey! This was texted to our group number, (864) 326-1314, from phone number #{params[:from]}! --- #{params[:text]}"
                      }

    mg_client.send_message 'mg.rebootcreate.com', message_params
  end

end
require "fastlane/action"
require "spaceship"
require_relative "../helper/taiwan_number_one_helper"

module Fastlane
  module Actions
    class TaiwanNumberOneAction < Action
      module DecisionType
        RELEASE = "release"
        REJECT = "reject"
      end

      module ActionResult
        SUCCESS = "Success"
        DO_NOTHING = "Nothing has changed"
      end

      def self.run(params)
        begin
          params[:api_key] ||= Actions.lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]

          app_id = params.fetch(:app_identifier)
          username = params.fetch(:username)
          unless app_id && username
            UI.message("Could not find app_id and username.")
            return
          end

          token = self.api_token(params)
          if token
            UI.message("Using App Store Connect API token...")
            Spaceship::ConnectAPI.token = token
          else
            UI.message("Login to App Store Connect (#{params[:username]})")
            Spaceship::ConnectAPI.login(
              params[:username],
              use_portal: false,
              use_tunes: true,
              tunes_team_id: params[:team_id],
              team_name: params[:team_name]
            )
            UI.message("Login successful")
          end

          app = Spaceship::ConnectAPI::App.find(app_id)
          version = app.get_app_store_versions.first
          UI.message("app_store_state is #{version.app_store_state}")
          client ||= Spaceship::ConnectAPI
          platform ||= Spaceship::ConnectAPI::Platform::IOS
          filter = {
            appStoreState: [
              Spaceship::ConnectAPI::AppStoreVersion::AppStoreState::PENDING_DEVELOPER_RELEASE
            ].join(","),
            platform: platform
          }
                    
          if params[:force] && decision == DecisionType::REJECT
            UI.message("decision is reject")
            app_store_version = app.get_app_store_versions(client: client, includes: "appStoreVersionSubmission")
                                 .sort_by { |v| Gem::Version.new(v.version_string) }
                                 .last
            return reject_version_if_possible(app: app, app_store_version: app_store_version)
          end

          app_store_version = app.get_app_store_versions(client: client, filter: filter, includes: "appStoreVersionSubmission")
                                 .sort_by { |v| Gem::Version.new(v.version_string) }
                                 .last
          if app_store_version
            version_string = app_store_version.version_string
            state = app_store_version.app_store_state
            UI.message("version #{version_string} is #{state}")
            unless state == Spaceship::ConnectAPI::AppStoreVersion::AppStoreState::PENDING_DEVELOPER_RELEASE
              UI.message("AppStoreState is not PENDING_DEVELOPER_RELEASE")
              UI.message("🇹🇼 Taiwan helps you do nothing!")
              return ActionResult::DO_NOTHING
            end
            decision ||= fetch_decision(params)

            result = ActionResult::DO_NOTHING
            case decision
            when DecisionType::RELEASE
              UI.message("decision is release")
              result = release_version_if_possible(app: app, app_store_version: app_store_version, token: token)
            when DecisionType::REJECT
              UI.message("decision is reject")
              result = reject_version_if_possible(app: app, app_store_version: app_store_version)
            else
              UI.user_error!("App's decision must be release or reject")
              result = ActionResult::DO_NOTHING
            end

            UI.message("The taiwan_number_one plugin action is finished!")
            UI.message("🇹🇼 Taiwan can help!")
            return result
          else
            UI.message("no pending release version exist.")
            UI.message("The taiwan_number_one plugin action is finished!")
            UI.message("🇹🇼 Taiwan can help!")
            return ActionResult::DO_NOTHING
          end
        rescue => error
          UI.message("🇹🇼 Taiwan might not be able to help you with this...")
          UI.user_error!("The taiwan_number_one plugin action is finished with error: #{error.message}!")
          return ActionResult::DO_NOTHING
        end
      end

      def self.fetch_decision(params)
        decision = params[:app_decision]
        until ["release", "reject"].include?(decision)
          UI.user_error!("App's decision must be release or reject.")
          return
        end
        # return decision
        UI.message("return type #{decision}")
        if decision == DecisionType::RELEASE
          return DecisionType::RELEASE
        else
          return DecisionType::REJECT
        end
      end

      def self.release_version_if_possible(app: nil, app_store_version: Spaceship::ConnectAPI::AppStoreVersion, token: nil)
        unless app
          UI.user_error!("Could not find app with bundle identifier '#{params[:app_identifier]}' on account #{params[:username]}")
          return ActionResult::DO_NOTHING
        end

        begin
          if token 
            now = Time.now
            release_date_string = now.strftime("%Y-%m-%dT%H:00%:z")
            app_store_version.update(attributes: {
                earliest_release_date: release_date_string,
                release_type: Spaceship::ConnectAPI::AppStoreVersion::ReleaseType::SCHEDULED
            })
            return ActionResult::SUCCESS
          else
            app_store_version.create_app_store_version_release_request
            UI.message("release version #{app_store_version.version_string} successfully!")
            return ActionResult::SUCCESS
          end
        rescue => e
          UI.user_error!("An error occurred while releasing version #{app_store_version}, #{e.message}\n#{e.backtrace.join("\n")}")
          return ActionResult::DO_NOTHING
        end
      end

      def self.reject_version_if_possible(app: nil, app_store_version: Spaceship::ConnectAPI::AppStoreVersion)
        unless app
          UI.user_error!("Could not find app with bundle identifier '#{params[:app_identifier]}' on account #{params[:username]}")
          return ActionResult::DO_NOTHING
        end

        if app_store_version.reject!
          UI.success("rejected version #{app_store_version.version_string} Successfully!")
          return ActionResult::SUCCESS
        else
          UI.user_error!("An error occurred while rejected version #{app_store_version}")
          return ActionResult::DO_NOTHING
        end
      end

      def self.api_token(params)
        params[:api_key] ||= Actions.lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
        api_token ||= Spaceship::ConnectAPI::Token.create(params[:api_key]) if params[:api_key]
        api_token ||= Spaceship::ConnectAPI::Token.from_json_file(params[:api_key_path]) if params[:api_key_path]
        return api_token
      end

      def self.description
        "release or reject if status is Pending Developer Release."
      end

      def self.authors
        ["andrew54068"]
      end

      def self.return_value
        return "'Success' if action passes, else, 'Nothing has changed'"
      end

      def self.details
        "use fastlane to release or reject reviewed version"
      end

      def self.output
        [
          [ActionResult::SUCCESS, 'Successfully release or reject.'],
          [ActionResult::DO_NOTHING, 'Do nothing.']
        ]
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)
        [
          FastlaneCore::ConfigItem.new(key: :app_decision,
                                       env_name: "app_decision",
                                       description: "A description of your decision, should be release or reject",
                                       optional: false,
                                       default_value: DecisionType::RELEASE,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :username,
                                       short_option: "-u",
                                       env_name: "username",
                                       description: "Your Apple ID Username",
                                       default_value: user,
                                       default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                       short_option: "-a",
                                       env_name: "app_identifier",
                                       description: "The bundle identifier of your app",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
                                       default_value_dynamic: true),
          # affiliation
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       short_option: "-k",
                                       env_name: "team_id",
                                       description: "The ID of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       is_string: false, # as we also allow integers, which we convert to strings anyway
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       short_option: "-e",
                                       env_name: "team_name",
                                       description: "The name of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_name),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :api_key_path,
                                       env_name: "FL_REGISTER_DEVICE_API_KEY_PATH",
                                       description: "Path to your App Store Connect API Key JSON file (https://docs.fastlane.tools/app-store-connect-api/#using-fastlane-api-key-json-file)",
                                       optional: true,
                                       conflicting_options: [:api_key],
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find API key JSON file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "FL_REGISTER_DEVICE_API_KEY",
                                       description: "Your App Store Connect API Key information (https://docs.fastlane.tools/app-store-connect-api/#use-return-value-and-pass-in-as-an-option)",
                                       type: Hash,
                                       optional: true,
                                       sensitive: true,
                                       conflicting_options: [:api_key_path]),
          FastlaneCore::ConfigItem.new(key: :force,
                                       env_name: "FL_DECISION_FORCE",
                                       description: "Skip verifying of current version state for reject reviewed version or cancel waiting review version",
                                       is_string: false,
                                       default_value: false),
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        [:ios, :mac].include?(platform)
      end

      def self.example_code
        [
          'taiwan_number_one(
            app_decision: "release",
            api_key: "api_key" # your app_store_connect_api_key
          )'
        ]
      end
    end
  end
end

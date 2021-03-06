require "fastlane/action"
require "Spaceship"
require_relative "../helper/taiwan_number_one_helper"

module Fastlane
  module Actions
    class TaiwanNumberOneAction < Action
      module DicisionType
        RELEASE = "release"
        REJECT = "reject"
      end

      def self.run(params)
        app_id = params.fetch(:app_identifier)
        username = params.fetch(:username)
        unless app_id && username
          UI.message("Could not find app_id and username.")
          return
        end

        # Prompts select team if multiple teams and none specified
        UI.message("Login to App Store Connect (#{params[:username]})")
        Spaceship::ConnectAPI.login(
          params[:username],
          use_portal: false,
          use_tunes: true,
          tunes_team_id: params[:team_id],
          team_name: params[:team_name]
        )
        UI.message("Login successful")

        # Get App
        application = Spaceship::Application.find(app_id)
        unless application
          UI.user_error!("Could not find app with bundle identifier '#{app_id}' on account #{params[:username]}")
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
        app_store_version = app.get_app_store_versions(client: client, filter: filter, includes: "appStoreVersionSubmission")
                               .sort_by { |v| Gem::Version.new(v.version_string) }
                               .last
        if app_store_version
          version_string = app_store_version.version_string
          state = app_store_version.app_store_state
          UI.message("version #{version_string} is #{state}")
          unless state == Spaceship::ConnectAPI::AppStoreVersion::AppStoreState::PENDING_DEVELOPER_RELEASE
            UI.message("AppStoreState is not PENDING_DEVELOPER_RELEASE")
            return
          end
          decision = params[:app_decision]
          decision ||= fetch_decision
          case decision
          when DicisionType::RELEASE
            UI.message("decision is release")
            release_version_if_possible(app: application, app_store_version: app_store_version)
          when DicisionType::REJECT
            UI.message("decision is reject")
            reject_version_if_possible(app: app, app_store_version: app_store_version)
          else
            decision ||= fetch_decision
          end
        else
          UI.message("no pending release version exist.")
        end
        UI.message("The taiwan_number_one plugin action is finished!")
      end

      def self.fetch_decision
        decision = nil
        until ["release", "reject"].include?(decision)
          decision = UI.input("Please enter the app's release decision (release, reject): ")
          UI.message("App's decision must be release or reject")
        end
        # return decision
        UI.message("return type #{decision}")
        if decision == DicisionType::RELEASE
          return DicisionType::RELEASE
        else
          return DicisionType::REJECT
        end
      end
      
      def self.release_version_if_possible(app: nil, app_store_version: Spaceship::ConnectAPI::AppStoreVersion)
        unless app
          UI.user_error!("Could not find app with bundle identifier '#{params[:app_identifier]}' on account #{params[:username]}")
        end

        begin
          app_store_version.create_app_store_version_release_request
          UI.message("release version #{app_store_version.version_string} successfully!")
        rescue => e
          UI.user_error!("An error occurred while releasing version #{app_store_version}")
          UI.error("#{e.message}\n#{e.backtrace.join("\n")}") if FastlaneCore::Globals.verbose?
        end
      end

      def self.reject_version_if_possible(app: nil, app_store_version: Spaceship::ConnectAPI::AppStoreVersion)
        unless app
          UI.user_error!("Could not find app with bundle identifier '#{params[:app_identifier]}' on account #{params[:username]}")
        end
        
        if app_store_version.reject!
          UI.success("rejected version #{app_store_version} Successfully!")
        else
          UI.user_error!("An error occurred while rejected version #{app_store_version}")
        end
      end

      def self.description
        "release or reject if status is Pending Developer Release."
      end

      def self.authors
        ["andrew54068"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "use fastlane to release or reject reviewed version"
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)
        [
          FastlaneCore::ConfigItem.new(key: :app_decision,
                                       env_name: "app_decision",
                                       description: "A description of your decision, should be release or reject",
                                       optional: false,
                                       default_value: DicisionType::RELEASE,
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
                                       end)
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
            app_decision: "release", # Set to true to skip verification of HTML preview
          )'
        ]
      end
    end
  end
end

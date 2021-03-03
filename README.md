# taiwan_number_one plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-taiwan_number_one)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-taiwan_number_one`, add it to your project by running:

```bash
fastlane add_plugin taiwan_number_one
```

## About taiwan_number_one

To approve or reject if status is Pending Developer Release.

#### This feature is requsted for a while:

Release app using fast lane (change status from "Pending Developer Release" to released
https://github.com/fastlane/fastlane/issues/11842

Ability to "Release This Version" from "Pending Developer Release"
https://github.com/fastlane/fastlane/issues/3481

Cancel "Pending developer release"?
https://developer.apple.com/forums/thread/53463

deliver not updating version number if app Pending Developer Release
https://github.com/fastlane/fastlane/issues/14154

[Deliver] - Not able to reject the app version which is in Pending Developer Release
https://github.com/fastlane/fastlane/issues/17539

## Usage

##### Show info

```
bundle exec fastlane action taiwan_number_one
```

##### Use in a Fastfile

you can create a custom lane like this:
```
desc "handle app release decision"
lane :release_decision do |options|
  taiwan_number_one(
    username: username,
    app_identifier: app_identifier,
    app_decision: options[:app_decision]
  )
end
```

Since there might have some problem in `reject_if_possible` of `Deliver`, so it's better to call this Action before `Deliver` everytime.

something like this:
```
desc "build and upload production app with info to App Store Connet"
lane :upload_production_and_testFlight do |options|
  ...
  release_decision(app_decision: options[:app_decision])
  deliver(...)
  ...
end
```

or 

```
release_decision(app_decision: Fastlane::Actions::TaiwanNumberOneAction::DicisionType::RELEASE)

release_decision(app_decision: Fastlane::Actions::TaiwanNumberOneAction::DicisionType::REJECT)
```

#### Use in terminal

Run `taiwan_number_one` to release or reject only when the reviewed version status is `Pending Developer Release`, otherwise do nothing.

```
bundle exec fastlane release_decision app_decision:"reject" username:"your apple id" app_identifier:"bundle id"
bundle exec fastlane release_decision app_decision:"release" username:"your apple id" app_identifier:"bundle id"
```

##### Default values
`taiwan_number_one` has a default `release` app_decision, which allow you to release the `Pending Developer Release` version when you don’t provide a specific app_decision value.

## Parameters
Key           | Description            |   Default |
--------------|:----------------------:|------------------------
app_decision  |A description of your decision, should be release or reject. |release|
username      |Your Apple ID Username                                       |
app_identifier|The bundle identifier of your app                            |
team_id       |The ID of your App Store Connect team if you're in multiple teams. (optional)|
team_name     |The name of your App Store Connect team if you're in multiple teams. (optional)|

## Run tests for this plugin

Not supported right now.

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

## Contributing

Simply create a PR. I'll take a look as soon as possible.

## Contact

andrew0424718012@gmail.com
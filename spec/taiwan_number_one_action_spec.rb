describe Fastlane::Actions::TaiwanNumberOneAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("Login to App Store Connect (dev@portto.io)")
      expect(Fastlane::UI).to receive(:message).with("Login successful")
      expect(Fastlane::UI).to receive(:message).with("app_store_state is PREPARE_FOR_SUBMISSION")
      expect(Fastlane::UI).to receive(:message).with("no pending release version exist.")
      expect(Fastlane::UI).to receive(:message).with("The taiwan_number_one plugin action is finished!")

      Fastlane::Actions::TaiwanNumberOneAction.run({
        app_identifier: "com.portto.Blocto-staging",
        username: "dev@portto.io",
        app_decision: "release"
        })
    end
  end
end

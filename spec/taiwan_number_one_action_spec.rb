describe Fastlane::Actions::TaiwanNumberOneAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The taiwan_number_one plugin is working!")

      Fastlane::Actions::TaiwanNumberOneAction.run(nil)
    end
  end
end

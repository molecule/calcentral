describe CampusSolutions::TransferCredit do

  let(:user_id) { '61889' }

  shared_examples 'a proxy that gets data' do
    subject { proxy.get }
    it_should_behave_like 'a simple proxy that returns errors'
    it_behaves_like 'a proxy that got data successfully'
    it 'returns data with the expected structure' do
      expect(subject[:feed][:root][:ucTransferCredits][:transferCredit][:ucTransferCrseSch]).to be
      expect(subject[:feed][:root][:ucTransferCredits][:transferCredit][:ucTestComponent]).to be
    end
  end

  context 'mock proxy' do
    let(:proxy) { CampusSolutions::TransferCredit.new(user_id: user_id, fake: true) }
    it_should_behave_like 'a proxy that gets data'
  end

end

describe IGMarkets::DealingPlatform::PositionMethods do
  let(:session) { IGMarkets::Session.new }
  let(:platform) do
    IGMarkets::DealingPlatform.new.tap do |platform|
      platform.instance_variable_set :@session, session
    end
  end

  it 'can retrieve the current positions' do
    positions = [build(:position)]

    get_result = {
      positions: positions.map(&:attributes).map do |a|
        { market: a[:market], position: a }
      end
    }

    expect(session).to receive(:get).with('positions', IGMarkets::API_V2).and_return(get_result)
    expect(platform.positions.all).to eq(positions)
  end

  it 'can retrieve a single position' do
    position = build :position

    expect(session).to receive(:get)
      .with("positions/#{position.deal_id}", IGMarkets::API_V2)
      .and_return(position: position.attributes, market: position.market)

    expect(platform.positions[position.deal_id]).to eq(position)
  end

  it 'can create a position' do
    attributes = {
      currency_code: 'USD',
      direction: :buy,
      epic: 'CS.D.EURUSD.CFD.IP',
      size: 2.0
    }

    payload = {
      currencyCode: 'USD',
      direction: 'BUY',
      epic: 'CS.D.EURUSD.CFD.IP',
      expiry: '-',
      forceOpen: false,
      guaranteedStop: false,
      orderType: 'MARKET',
      size: 2.0,
      timeInForce: 'EXECUTE_AND_ELIMINATE'
    }

    result = { deal_reference: 'reference' }

    expect(session).to receive(:post).with('positions/otc', payload, IGMarkets::API_V2).and_return(result)
    expect(platform.positions.create(attributes)).to eq(result.fetch(:deal_reference))
  end

  it 'validates position creation attributes correctly' do
    attributes = {
      currency_code: 'USD',
      direction: :buy,
      epic: 'CS.D.EURUSD.CFD.IP',
      size: 2.0,
      time_in_force: :execute_and_eliminate
    }

    create_position = proc do |override_attributes = {}|
      platform.positions.create attributes.merge override_attributes
    end

    expect(session).to receive(:post).exactly(10).times.and_return(deal_reference: 'reference')

    expect { create_position.call }.to_not raise_error
    expect { create_position.call order_type: :quote }.to raise_error(ArgumentError)
    expect { create_position.call order_type: :quote, quote_id: 'a' }.to raise_error(ArgumentError)
    expect { create_position.call order_type: :quote, level: 1 }.to raise_error(ArgumentError)
    expect { create_position.call order_type: :quote, quote_id: 'a', level: 1 }.to_not raise_error
    expect { create_position.call order_type: :limit }.to raise_error(ArgumentError)
    expect { create_position.call order_type: :limit, level: 1 }.to_not raise_error
    expect { create_position.call trailing_stop: true, stop_distance: 1 }.to raise_error(ArgumentError)
    expect { create_position.call trailing_stop: true, stop_distance: 1, trailing_stop_increment: 1 }.not_to raise_error
    expect { create_position.call limit_distance: 1 }.not_to raise_error
    expect { create_position.call limit_level: 1 }.not_to raise_error
    expect { create_position.call limit_distance: 1, limit_level: 1 }.to raise_error(ArgumentError)
    expect { create_position.call stop_distance: 1 }.not_to raise_error
    expect { create_position.call stop_level: 1 }.not_to raise_error
    expect { create_position.call stop_distance: 1, stop_level: 1 }.to raise_error(ArgumentError)
    expect { create_position.call guaranteed_stop: true }.to raise_error(ArgumentError)
    expect { create_position.call guaranteed_stop: true, stop_distance: 1 }.not_to raise_error
    expect { create_position.call guaranteed_stop: true, stop_level: 1 }.not_to raise_error
  end

  it 'can update a position' do
    position = build :position, deal_id: '1'

    get_result = { position: position.attributes, market: position.market }
    payload = { limitLevel: 2.0, stopLevel: 1.0, trailingStop: false }
    put_result = { deal_reference: 'reference' }

    expect(session).to receive(:get).with('positions/1', IGMarkets::API_V2).and_return(get_result)
    expect(session).to receive(:put).with('positions/otc/1', payload, IGMarkets::API_V2).and_return(put_result)
    expect(platform.positions['1'].update(stop_level: 1, limit_level: 2)).to eq('reference')
  end

  it 'can close a position' do
    position = build :position, deal_id: '1', size: 5

    get_result = { position: position.attributes, market: position.market }
    payload = { dealId: '1', direction: 'SELL', orderType: 'MARKET', size: 5.0, timeInForce: 'EXECUTE_AND_ELIMINATE' }
    delete_result = { deal_reference: 'reference' }

    expect(session).to receive(:get).with('positions/1', IGMarkets::API_V2).and_return(get_result)
    expect(session).to receive(:delete).with('positions/otc', payload, IGMarkets::API_V1).and_return(delete_result)
    expect(platform.positions['1'].close).to eq('reference')
  end

  it 'validates position close attributes correctly' do
    position = build :position, deal_id: '1'
    position.instance_variable_set :@dealing_platform, platform

    attributes = { time_in_force: :execute_and_eliminate }

    close_position = proc do |override_attributes = {}|
      position.close attributes.merge override_attributes
    end

    expect(session).to receive(:delete).exactly(3).times.and_return(deal_reference: 'reference')

    expect { close_position.call }.to_not raise_error
    expect { close_position.call order_type: :quote }.to raise_error(ArgumentError)
    expect { close_position.call order_type: :quote, quote_id: 'a' }.to raise_error(ArgumentError)
    expect { close_position.call order_type: :quote, level: 1 }.to raise_error(ArgumentError)
    expect { close_position.call order_type: :quote, quote_id: 'a', level: 1 }.to_not raise_error
    expect { close_position.call order_type: :limit }.to raise_error(ArgumentError)
    expect { close_position.call order_type: :limit, level: 1 }.to_not raise_error
  end
end

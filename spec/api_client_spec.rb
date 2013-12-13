require 'spec_helper'

include GHTorrent::Settings
include GHTorrent::APIClient

describe 'The API client' do

  def stub_config(remaining, reset)
    stub_request(:get, "https://#{config(:github_username)}:#{config(:github_passwd)}@api.github.com/events").
        with(:headers => {'Accept'=>'*/*', 'User-Agent'=>'ghtorrent'}).
        to_return(:status => 200, :body => (1..30).to_a,
                  :headers => {'x-ratelimit-remaining' => remaining,
                               'x-ratelimit-reset' => reset})
  end

  it 'call /events should return 30 results' do
    stub_config(1000, 1000)
    r = api_request 'https://api.github.com/events', false
    expect(r.size).to eq(30)
  end

  it 'should resume from sleep' do
    time = Time.now.to_i
    stub_config(2, Time.now.to_i + 1)
    api_request 'https://api.github.com/events', false


    stub_config(1000, 1000)
    api_request 'https://api.github.com/events', false
    expect(Time.now.to_i - time).to be_within(0.3).of(3)
  end

  it 'should sleep for 7 seconds' do
    stub_config(2, Time.now.to_i + 5)

    time = Time.now.to_i
    api_request 'https://api.github.com/events', false
    expect(Time.now.to_i - time).to be_within(0.3).of(7)
  end

end


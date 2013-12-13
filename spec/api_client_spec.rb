require 'spec_helper'

describe 'The API client' do

  include GHTorrent::APIClient

  it 'call /events should return 30 results' do
    r = api_request 'https://api.github.org/events'
    expect(r.size).to eq(30)
  end

end
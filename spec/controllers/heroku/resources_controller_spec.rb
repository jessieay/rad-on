require 'rails_helper'

RSpec.describe Heroku::ResourcesController do
  describe 'POST /heroku/resources' do
    it 'returns a 200' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger

      post :create, params: {
        'uuid' => '123ABC',
        'plan' => 'test',
        'oauth_grant': {
          'code': 'supersecretcode'
        }
      }

      expect(response.code).to eq('200')
    end

    it 'returns the correct json response' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger
      heroku_uuid = '123-ABC-456-DEF'
      expected_response = {
        id: heroku_uuid,
        config: {
          SUDO_SANDWICH_COMMAND: 'Make me a PB&J!'
        },
        message: 'Thanks for using Sudo Sandwich.'
      }

      post :create, params: {
        'uuid' => heroku_uuid,
        'plan' => 'pbj',
        'oauth_grant': {
          'code': 'sekret'
        }
      }

      expect(parsed_response_body).to eq(expected_response)
    end

    it 'saves the plan and encrypted oauth grant code' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger
      heroku_uuid = '123-ABC-456-DEF'
      code = 'supersecretcode'

      post :create, params: {
        'uuid' => heroku_uuid,
        'plan' => 'pbj',
        'oauth_grant': {
          'code': code
        }
      }

      sandwich = Sandwich.find_by(heroku_uuid: heroku_uuid)

      expect(sandwich.oauth_grant_code).to eq(code)
      expect(sandwich.plan).to eq('pbj')
    end
  end

  describe 'PUT /heroku/resources' do
    it 'changes the plan for the heroku_uuid passed in' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      heroku_uuid = '123-ABC-456-DEF'
      old_plan = "pbj"
      new_plan = "blt"
      sandwich = Sandwich.create(heroku_uuid: heroku_uuid, plan: old_plan)

      put :update, params: { id: heroku_uuid, plan: new_plan }

      expect(sandwich.reload.plan).to eq new_plan
    end

    it 'returns the expected response' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      heroku_uuid = '123-ABC-456-DEF'
      old_plan = "pbj"
      new_plan = "blt"
      Sandwich.create(heroku_uuid: heroku_uuid, plan: old_plan)
      expected_response = {
        config: {
          SUDO_SANDWICH_COMMAND: 'Make me a BLT!'
        },
        message: 'Successfully changed from pbj to blt'
      }

      put :update, params: { id: heroku_uuid, plan: new_plan }

      expect(parsed_response_body).to eq(expected_response)
    end

    it 'enqueues the ExchangeGrantTokenJob' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger
      heroku_uuid = '123-ABC-456-DEF'
      code = 'supersecretcode'

      post :create, params: {
        'uuid' => heroku_uuid,
        'oauth_grant': {
          'code': code
        }
      }

      expect(ExchangeGrantTokenJob).to have_received(:perform_later).
        with(heroku_uuid: heroku_uuid, oauth_grant_code: code)
    end
  end

  describe 'POST /heroku/resources' do
    it 'returns a 204' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger
      heroku_uuid = '123-ABC'
      sandwich = double(destroy!: true)
      allow(Sandwich).to receive(:find_by).with(heroku_uuid: heroku_uuid).and_return(sandwich)

      delete :destroy, params: { 'id' => heroku_uuid }

      expect(response.code).to eq('204')
    end

    it 'deletes the associated sandwich record' do
      http_login(ENV['SLUG'], ENV['PASSWORD'])
      stub_grant_code_exchanger
      heroku_uuid = '123-ABC'
      Sandwich.create!(heroku_uuid: heroku_uuid)

      delete :destroy, params: { 'id' => heroku_uuid }

      sandwich = Sandwich.find_by(heroku_uuid: heroku_uuid)

      expect(sandwich).to be nil
    end
  end

  def parsed_response_body
    JSON.parse(response.body, symbolize_names: true)
  end

  def stub_grant_code_exchanger
    allow(ExchangeGrantTokenJob).to receive(:perform_later)
  end
end

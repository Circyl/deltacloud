$:.unshift File.join(File.dirname(__FILE__), '..', '..', '..')
require 'tests/drivers/rhevm/common'

module RHEVMTest

  class RealmsTest < Test::Unit::TestCase
    include Rack::Test::Methods

    def app
      Rack::Builder.new {
        map '/' do
          use Rack::Static, :urls => ["/stylesheets", "/javascripts"], :root => "public"
          run Rack::Cascade.new([Deltacloud::API])
        end
      }
    end

    def test_01_it_returns_realms
      get_auth_url '/api;driver=rhevm/realms'
      (last_xml_response/'realms/realm').length.should == 1
    end

    def test_02_each_realm_has_a_name
      get_auth_url '/api;driver=rhevm/realms'
      (last_xml_response/'realms/realm').each do |profile|
        (profile/'name').text.should_not == nil
        (profile/'name').text.should_not == ''
        (profile/'name').text.should_not == 'Default'
      end
    end

    def test_03_it_returns_single_realm
      get_auth_url '/api;driver=rhevm/realms/3c8af388-cff6-11e0-9267-52540013f702'
      (last_xml_response/'realm').first[:id].should == '3c8af388-cff6-11e0-9267-52540013f702'
      (last_xml_response/'realm/name').first.text.should == 'engops-nfs'
      (last_xml_response/'realm/state').first.text.should == 'AVAILABLE'
    end

  end
end

$:.unshift File.join(File.dirname(__FILE__), '..', '..', '..')
require 'tests/drivers/mock/common'

describe 'Deltacloud API Keys' do
  include Deltacloud::Test

  it 'must advertise have the keys collection in API entrypoint' do
    get Deltacloud[:root_url]
    (xml_response/'api/link[@rel=keys]').wont_be_empty
  end

  it 'must require authentication to access the "key" collection' do
    get collection_url(:keys)
    last_response.status.must_equal 401
  end

  it 'should respond with HTTP_OK when accessing the :keys collection with authentication' do
    auth_as_mock
    get collection_url(:keys)
    last_response.status.must_equal 200
  end

  it 'should support the JSON media type' do
    auth_as_mock
    header 'Accept', 'application/json'
    get collection_url(:keys)
    last_response.status.must_equal 200
    last_response.headers['Content-Type'].must_equal 'application/json'
  end

  it 'must include the ETag in HTTP headers' do
    auth_as_mock
    get collection_url(:keys)
    last_response.headers['ETag'].wont_be_nil
  end

  it 'must have the "keys" element on top level' do
    auth_as_mock
    get collection_url(:keys)
    xml_response.root.name.must_equal 'keys'
  end

  it 'must have some "key" elements inside "keys"' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').wont_be_empty
  end

  it 'must tell the kind of "key" elements inside "keys"' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |k|
      k[:type].must_match /(key|password)/
    end
  end

  it 'must provide the :id attribute for each key in collection' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      r[:id].wont_be_nil
    end
  end

  it 'must include the :href attribute for each "key" element in collection' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      r[:href].wont_be_nil
    end
  end

  it 'must use the absolute URL in each :href attribute' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      r[:href].must_match /^http/
    end
  end

  it 'must have the URL ending with the :id of the key' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      r[:href].must_match /#{r[:id]}$/
    end
  end

  it 'must return the list of valid parameters for the :index action' do
    auth_as_mock
    options collection_url(:keys) + '/index'
    last_response.headers['Allow'].wont_be_nil
  end

  it 'must have the "name" element defined for each key in collection' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      (r/'name').wont_be_empty
    end
  end


  it 'must return the full "key" when following the URL in key element' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      get collection_url(:keys) + '/' + r[:id]
      last_response.status.must_equal 200
    end
  end

  it 'must have the "name" element for the key and it should match with the one in collection' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      get collection_url(:keys) + '/' + r[:id]
      (xml_response/'name').wont_be_empty
      (xml_response/'name').first.text.must_equal((r/'name').first.text)
    end
  end

  it 'must have the "name" element for the key and it should match with the one in collection' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      get collection_url(:keys) + '/' + r[:id]
      (xml_response/'state').wont_be_empty
      (xml_response/'state').first.text.must_equal((r/'state').first.text)
    end
  end

  it 'should advertise the list of actions that can be executed for each key' do
    auth_as_mock
    get collection_url(:keys)
    (xml_response/'keys/key').each do |r|
      get collection_url(:keys) + '/' + r[:id]
      (xml_response/'actions/link').wont_be_empty
      (xml_response/'actions/link').each do |l|
        l[:href].wont_be_nil
        l[:href].must_match /^http/
        l[:method].wont_be_nil
        l[:rel].wont_be_nil
      end
    end
  end

  it 'should allow to create a new key and then remove it' do
    auth_as_mock
    key_name = Time.now.to_i.to_s
    post collection_url(:keys), {
      :name => 'test_key_'+key_name
    }
    last_response.status.must_equal 201 # HTTP_CREATED
    get collection_url(:keys) + '/' + 'test_key_'+key_name
    last_response.status.must_equal 200 # HTTP_OK
    delete collection_url(:keys) + '/' + 'test_key_'+key_name
    last_response.status.must_equal 204 # HTTP_NO_CONTENT
  end

end

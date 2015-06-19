require 'helper'

class TestDatatypes < ParseTestCase
  def test_pointer
    data = {
      Parse::Protocol::KEY_CLASS_NAME => 'DatatypeTestClass',
      Parse::Protocol::KEY_OBJECT_ID => '12345abcd'
    }
    p = Parse::Pointer.new data

    assert_equal p.to_json, "{\"__type\":\"Pointer\",\"#{Parse::Protocol::KEY_CLASS_NAME}\":\"DatatypeTestClass\",\"#{Parse::Protocol::KEY_OBJECT_ID}\":\"12345abcd\"}"
  end

  def test_pointer_make
    p = Parse::Pointer.make('SomeClass', 'someId')
    assert_equal 'SomeClass', p.class_name
    assert_equal 'someId', p.id
  end

  def test_date
    VCR.use_cassette('test_datatypes_date') do
      date_time = Time.at(0).to_datetime
      parse_date = Parse::Date.new(date_time)

      assert_equal date_time, parse_date.value
      assert_equal '1970-01-01T00:00:00.000Z', JSON.parse(parse_date.to_json)['iso']
      assert_equal 0, parse_date <=> parse_date.dup
      assert_equal 0, Parse::Date.new(date_time) <=> Parse::Date.new(date_time).dup

      post = Parse::Object.new('Post', nil, @client)
      post['time'] = parse_date
      post.save
      q = Parse.get('Post', post.id, @client)

      # time zone from parse is utc so string formats don't compare equal,
      # also floating points vary a bit so only equality after rounding to millis is guaranteed
      assert_equal parse_date.to_time.utc.to_datetime.iso8601(3), q['time'].to_time.utc.to_datetime.iso8601(3)
    end
  end

  def test_date_with_bad_data
    assert_raises(RuntimeError) do
      Parse::Date.new(2014)
    end

    assert_raises(RuntimeError) do
      Parse::Date.new(nil)
    end
  end

  def test_date_with_time
    time = Time.parse('01/01/2012 23:59:59')
    assert_equal time, Parse::Date.new(time).to_time
  end

  def test_bytes
    data = {
      'base64' => Base64.encode64('testing bytes!')
    }
    byte = Parse::Bytes.new data

    assert_equal byte.value, 'testing bytes!'
    assert_equal JSON.parse(byte.to_json)[Parse::Protocol::KEY_TYPE], Parse::Protocol::TYPE_BYTES
    assert_equal JSON.parse(byte.to_json)['base64'], Base64.encode64('testing bytes!')
  end

  def test_increment
    amount = 5
    increment = Parse::Increment.new amount

    assert_equal increment.to_json, "{\"__op\":\"Increment\",\"amount\":#{amount}}"
  end

  def test_geopoint
    VCR.use_cassette('test_datatypes_geopoint') do
      data = {
        'longitude' => 40.0,
        'latitude' => -30.0
      }

      geopoint = Parse::GeoPoint.new data

      pgp = JSON.parse(geopoint.to_json)
      assert_equal pgp['longitude'], data['longitude']
      assert_equal pgp['latitude'], data['latitude']
      assert_equal pgp[Parse::Protocol::KEY_TYPE], Parse::Protocol::TYPE_GEOPOINT

      post = Parse::Object.new('Post', nil, @client)
      post['location'] = geopoint
      post.save

      q = Parse.get('Post', post.id, @client)
      assert_equal geopoint, q['location']
    end
  end
end

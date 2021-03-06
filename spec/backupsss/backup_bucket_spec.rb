require 'spec_helper'
require 'backupsss/backup_bucket'

describe Backupsss::BackupBucket do
  let(:list_objects_response) do
    {
      is_truncated: false,
      marker: '',
      contents: [
        {
          key:           'mah_bucket/mah/key/1455049150.tar',
          last_modified: Time.new('2016-02-09 20:52:03 UTC'),
          etag:          'somecrazyhashthinffffffffffsddf',
          size:          10_240,
          storage_class: 'STANDARD',
          owner: {
            display_name: 'theowner',
            id:           'ownderidhasthinglkajsdlkjasdflkj'
          }
        },
        {
          key:           'mah_bucket/mah/key/1455049148.tar',
          last_modified: Time.new('2016-02-09 20:50:01 UTC'),
          etag:          'somecrazyhashthinglkjsdlfkjsdf',
          size:          10_240,
          storage_class: 'STANDARD',
          owner: {
            display_name: 'theowner',
            id:           'ownderidhasthinglkajsdlkjasdflkj'
          }
        }
      ],
      name:          'mah_bucket',
      prefix:        'mah/key',
      max_keys:      1000,
      encoding_type: 'url'
    }
  end

  let(:delete_object_response) do
    {
      delete_marker: nil,
      version_id: nil,
      request_charged: nil
    }
  end

  let(:s3_stub) do
    s3 = Aws::S3::Client.new(stub_responses: true)
    s3.stub_responses(:list_objects, list_objects_response)
    s3.stub_responses(:delete_object, delete_object_response)
    s3
  end

  let(:dir)           { 'mah_bucket/mah/key' }
  let(:region)        { 'us-east-1' }
  let(:backup_bucket) do
    Backupsss::BackupBucket.new(dir: dir, region: region)
  end

  before(stub_s3: true) do
    allow(backup_bucket).to receive(:s3_client).and_return(s3_stub)
  end

  describe '#initialize' do
    context 'dir' do
      subject { backup_bucket.dir }
      it      { is_expected.to eq(dir) }
    end

    context 'region' do
      subject { backup_bucket.region }
      it      { is_expected.to eq(region) }
    end
  end

  describe '#ls' do
    it 'returns an array of s3 objects', stub_s3: true do
      expected_files = [
        'mah_bucket/mah/key/1455049148.tar',
        'mah_bucket/mah/key/1455049150.tar'
      ]
      expect(backup_bucket.ls).to match_array(expected_files)
    end
  end

  describe '#ls_t' do
    it 'returns an array of s3 objects ordered newest to oldest',
       stub_s3: true do
      expected_files = [
        'mah_bucket/mah/key/1455049150.tar',
        'mah_bucket/mah/key/1455049148.tar'
      ]
      expect(backup_bucket.ls_t).to eq(expected_files)
    end
  end

  describe '#ls_rt' do
    it 'returns an array of s3 objects ordered oldest to newest',
       stub_s3: true do
      expected_files = [
        'mah_bucket/mah/key/1455049148.tar',
        'mah_bucket/mah/key/1455049150.tar'
      ]

      expect(backup_bucket.ls_rt).to eq(expected_files)
    end
  end

  describe '#rm' do
    it 'should call delete_object', stub_s3: true do
      expect(s3_stub).to receive(:delete_object)
        .with(bucket: 'mah_bucket', key: 'mah/key/1455049150.tar')

      backup_bucket.rm('mah/key/1455049150.tar')
    end

    context 'when the object is deleted succesfully', stub_s3: true do
      subject { backup_bucket.rm('1455049150.tar') }
      it { is_expected.to eq('1455049150.tar') }
    end
  end
end

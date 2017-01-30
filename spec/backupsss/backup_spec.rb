require 'spec_helper'
require 'backupsss/backup'
require 'aws-sdk'

describe Backupsss::Backup, :ignore_stdout do
  let(:filename)    { 'somekey.tar' }
  let(:key)         { "some_prefix/#{filename}" }
  let(:backup)      { Backupsss::Backup.new(config_hash, client) }
  let(:filesize)    { 0 }
  let(:bucket_opts) { { bucket: 'some_bucket', key: key } }
  let(:sm)          { 1024 * 1024 * 100 }
  let(:lg)          { 1024 * 1024 * 150 }
  let(:max_size)    { sm }
  let(:upload_id)   { 'AvErYV3rYv3RYveryVERYLooOOOooOOOooooOO000ngUpl0@d!d!!!' }
  let(:aws_stubs)   { {} }
  let(:config_hash) do
    {
      s3_bucket_prefix: 'some_prefix',
      s3_bucket: 'some_bucket',
      filename: filename
    }
  end

  let(:file) do
    instance_double('File', read: 'foo', path: filename, size: filesize)
  end

  let(:client) do
    c = Aws::S3::Client.new(stub_responses: true)
    aws_stubs.each do |msg, resp|
      c.stub_responses(msg.to_sym, resp)
    end

    c
  end

  before do
    allow(IO).to receive(:read).and_return('foo')
  end

  describe '#put_file' do
    context 'while checking filesize' do
      it 'informs of activity' do
        info = 'Checking backup size ...'

        expect { backup.put_file(file) }
          .to output(/#{info}/).to_stdout
      end
    end

    context 'with a file < 100 MB' do
      let(:filesize)  { sm }
      let(:aws_stubs) { { put_object: nil } }

      it 'informs about a small file' do
        info = 'Size of backup is less than or equal to 100MB'

        expect { backup.put_file(file) }
          .to output(/#{info}/).to_stdout
      end

      it 'sends put_object to the client once' do
        expect(client).to receive(:put_object).once

        backup.put_file(file)
      end
    end

    context 'with a file > 100 MB' do
      let(:filesize) { lg }
      let(:aws_stubs) do
        {
          upload_part: (1..2).map { { etag: 'ETag' } },
          create_multipart_upload: {
            upload_id: upload_id
          },
          complete_multipart_upload: {
            bucket: bucket_opts[:bucket],
            key:    bucket_opts[:key]
          }
        }
      end

      it 'informs about a large file' do
        info = 'Size of backup is greater than 100MB'

        expect { backup.put_file(file) }
          .to output(/#{info}/).to_stdout
      end

      it 'informs about part count' do
        info = 'Uploading backup as 2 parts'

        expect { backup.put_file(file) }
          .to output(/#{info}/).to_stdout
      end

      context 'while creating multi part upload' do
        it 'informs about activity' do
          info = 'Creating a multipart upload'

          expect { backup.put_file(file) }
            .to output(/#{info}/).to_stdout
        end
      end

      context 'while uploading parts' do
        it 'informs about activity' do
          infos = (1..2).map do |i|
            "Uploading part number #{i} : #{upload_id}"
          end

          expect { backup.put_file(file) }
            .to output(/#{infos[0]}.*#{infos[1]}/m).to_stdout
        end

        it 'sends upload_part to the client for each part' do
          (1..2).each do |i|
            expect(client).to receive(:upload_part)
              .with(hash_including(upload_id: upload_id, part_number: i))
              .and_call_original
          end

          backup.put_file(file)
        end

        context 'and all parts succeed' do
          it 'informs about successes' do
            expect { backup.put_file(file) }
              .to output(/Completed uploading part number [12]/m).to_stdout
          end

          it 'sends complete_multipart_upload to the client once' do
            params = {
              upload_id: upload_id,
              multipart_upload: {
                parts: (1..2).map { |i| { etag: 'ETag', part_number: i } }
              }
            }

            expect(client).to receive(:complete_multipart_upload)
              .with(hash_including(params)).once

            backup.put_file(file)
          end
        end

        context 'and some parts failed' do
          let(:error) { Timeout::Error.new('Took too long foo!') }
          let(:aws_stubs) do
            {
              upload_part: [
                error,
                { etag: 'ETag' }
              ],
              create_multipart_upload: {
                upload_id: upload_id
              },
              complete_multipart_upload: {
                bucket: bucket_opts[:bucket],
                key:    bucket_opts[:key]
              }
            }
          end

          context 'handles and informs about different Exceptions' do
            context 'Timeout error' do
              it 'informs about error with message' do
                info = 'because of Took too long foo!'

                expect { backup.put_file(file) }
                  .to output(/#{info}/).to_stdout
              end
            end

            context 'NotFound error' do
              let(:error) { 'NotFound' }

              it 'informs about error with message' do
                info = 'because of stubbed-response-error-message'

                expect { backup.put_file(file) }
                  .to output(/#{info}/).to_stdout
              end
            end
          end

          it 'informs about failure with offending part number' do
            info = "Failed to upload part number 1 : #{upload_id}"

            expect { backup.put_file(file) }
              .to output(/#{info}/).to_stdout
          end

          it 'does not call upload part for part 2' do
            expect(client).to receive(:upload_part).once.and_call_original

            backup.put_file(file)
          end

          it 'informs about aborting remaining parts' do
            infos = "Aborting remaining parts : #{upload_id}"

            expect { backup.put_file(file) }
              .to output(/#{infos}/).to_stdout
          end

          it 'calls abort_multipart_upload and notifies' do
            params = {
              bucket: bucket_opts[:bucket],
              key:    bucket_opts[:key],
              upload_id: upload_id
            }

            expect(client).to receive(:abort_multipart_upload)
              .with(hash_including(params)).once

            expect { backup.put_file(file) }
              .to output(/Aborting multipart upload : #{upload_id}/).to_stdout
          end
        end
      end
    end
  end
end

require 'spec_helper'
require 'backupsss/tar'

describe Backupsss::Tar, :ignore_stdout do
  let(:empty_src) { 'spec/fixtures/backup_src/empty' }
  let(:valid_src) { 'spec/fixtures/backup_src/with_data' }
  let(:src)       { 'spec/fixtures/backup_src' }
  let(:filename)  { 'backup.tar' }
  let(:dest)      { "spec/fixtures/backups_dest/#{filename}" }
  after(:all)     { FileUtils.rm('spec/fixtures/backups_dest/backup.tar') }

  describe '#filename' do
    subject { Backupsss::Tar.new(valid_src, dest).filename }

    it { is_expected.to eq(filename) }
  end

  describe '#valid_src?' do
    context 'when src does not exist on the file system' do
      subject { -> { Backupsss::Tar.new('does_not_exist', '').valid_src? } }

      it { is_expected.to raise_error(Errno::ENOENT) }
      it { is_expected.to raise_error(/does_not_exist$/) }
    end

    context 'when src is not readable' do
      subject { -> { Backupsss::Tar.new(empty_src, '').valid_src? } }
      before  { allow(File).to receive(:readable?) { false } }

      it { is_expected.to raise_error(Errno::EPERM) }
      it { is_expected.to raise_error(/#{empty_src}$/) }
    end

    context 'when src exists and is readable' do
      subject { Backupsss::Tar.new(valid_src, '').valid_src? }

      it { is_expected.to be true }
    end
  end

  describe '#valid_dest?' do
    context 'when dest dir does not exist on the file system' do
      let(:invalid_dest) { "spec/fixtures/invalid/#{filename}" }
      subject { -> { Backupsss::Tar.new(valid_src, invalid_dest).valid_dest? } }

      it { is_expected.to raise_error(Errno::ENOENT) }
      it { is_expected.to raise_error(%r{spec\/fixtures\/invalid$}) }
    end

    context 'when dest dir is not writable' do
      subject { -> { Backupsss::Tar.new(valid_src, dest).valid_dest? } }
      before { allow(File).to receive(:writable?) { false } }

      it { is_expected.to raise_error(Errno::EPERM) }
      it { is_expected.to raise_error(/#{File.dirname(dest)}$/) }
    end

    context 'when dest dir exists and is writable' do
      before  { allow(File).to receive(:writable?) { true } }
      subject { Backupsss::Tar.new('', dest).valid_dest? }

      it { is_expected.to be true }
    end
  end

  describe '#tar_command' do
    context 'compress_archive true' do
      subject { Backupsss::Tar.new('src/', 'dest.tar').tar_command }

      it { is_expected.to eq('tar -zcvf') }
    end

    context 'compress_archive false' do
      subject { Backupsss::Tar.new('src/', 'dest.tar', false).tar_command }

      it { is_expected.to eq('tar -cvf') }
    end
  end

  describe '#make' do
    context 'when src and dest dir exist with correct permissions' do
      subject { Backupsss::Tar.new(valid_src, dest) }

      it 'returns a File object' do
        expect(subject.make).to be_kind_of(File)
      end

      it 'exits cleanly' do
        expect { subject.make }.to_not raise_error
      end
    end
  end

  describe '#valid_file?' do
    let(:missing_msg)   { 'ERROR: Tar destination file does not exist.' }
    let(:zero_byte_msg) { 'ERROR: Tar destination file is 0 bytes.' }
    subject { -> { Backupsss::Tar.new(valid_src, dest).valid_file? } }

    context 'when file is missing' do
      before { allow(File).to receive(:exist?).with(dest).and_return(false) }

      it { is_expected.to raise_error(missing_msg) }
    end

    context 'when file is 0 bytes' do
      before do
        allow(File).to receive(:size).with(dest).and_return(0)
        allow(File).to receive(:exist?).with(dest).and_return(true)
      end

      it { is_expected.to raise_error(zero_byte_msg) }
    end

    context 'when file exists and is a valid size' do
      before do
        allow(File).to receive(:size).with(dest).and_return(1)
        allow(File).to receive(:exist?).with(dest).and_return(true)
      end

      subject { Backupsss::Tar.new(valid_src, dest).valid_file? }

      it { is_expected.to eq(true) }
    end
  end

  describe '#valid_exit?' do
    Status = Struct.new(:to_i, :to_s)
    let(:err) { '' }

    context 'when status is zero' do
      let(:status) { Status.new(0, 'pid 18327 exit 0') }
      subject { Backupsss::Tar.new(valid_src, dest).valid_exit?(status, err) }

      it { is_expected.to eq(true) }
    end

    context 'when status is greater than 1' do
      let(:status) { Status.new(2, 'pid 21320 SIGINT (signal 2)') }
      subject do
        -> { Backupsss::Tar.new(valid_src, dest).valid_exit?(status, err) }
      end

      it { is_expected.to raise_error(/ERROR: tar.* exited #{status.to_i}/) }
    end

    context 'when error is a valid warning' do
      let(:exit_code)       { 1 }
      let(:status_msg)      { 'pid 8 exit 1' }
      let(:status)          { Status.new(exit_code, status_msg) }
      let(:err)             { 'file: file changed as we read it' }
      let(:expected_output) do
        [
          "command.......tar -zcvf\n",
          "stderr........#{err}\n",
          "status........#{status_msg}\n",
          "exit code.....#{exit_code}\n"
        ].join
      end

      subject do
        Backupsss::Tar.new(valid_src, dest).valid_exit?(status, err)
      end

      it { is_expected.to eq(true) }

      context 'no error and output' do
        subject do
          -> { Backupsss::Tar.new(valid_src, dest).valid_exit?(status, err) }
        end

        it { is_expected.to_not raise_error }
        it { is_expected.to output(expected_output).to_stdout }
      end
    end
  end
end

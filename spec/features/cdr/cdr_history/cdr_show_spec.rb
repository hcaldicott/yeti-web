# frozen_string_literal: true

RSpec.describe 'CDR show', type: :feature do
  subject do
    visit cdr_path(id: cdr.id)
  end

  include_context :login_as_admin
  include_context :init_routing_tag_collection

  let!(:cdr) do
    create(:cdr, :with_id, cdr_attrs)
  end
  let(:cdr_attrs) do
    {
      time_start: 1.hour.ago.utc,
      routing_tag_ids: [tag_ua.id, tag_us.id]
    }
  end

  it 'shows CDR with correct attributes' do
    subject
    expect(page).to have_table_row(count: 1)
    expect(page).to have_attribute_row('ID', exact_text: cdr.id)
    expect(find(attributes_row_selector('Routing Tags')).text.split).to match_array([tag_ua.name, tag_us.name])
    within_attribute_row('Routing Tags') do
      expect(page).to have_selector('.status_tag.ok', text: tag_ua.name)
      expect(page).to have_selector('.status_tag.ok', text: tag_us.name)
    end
  end

  it 'shows attempts table' do
    subject
    expect(page).to have_table_row(count: 1)
    expect(page).to have_table_cell(column: 'Id', exact_text: cdr.id)
    expect(find(table_cell_selector('Routing Tags')).text.split).to match_array([tag_ua.name, tag_us.name])
    within_table_cell('Routing Tags') do
      expect(page).to have_selector('.status_tag.ok', exact_text: tag_ua.name)
      expect(page).to have_selector('.status_tag.ok', exact_text: tag_us.name)
    end
  end

  it 'does not have link to create new cdr' do
    subject
    expect(page).to have_selector('tr.row-routing_tags')
    expect(page).to_not have_selector('.title_bar .action_items .action_item a[href="/cdrs/new"]')
  end

  context 'when CDR has no routing tags' do
    let(:cdr_attrs) do
      super().merge routing_tag_ids: []
    end

    it 'shows CDR with correct attributes' do
      subject
      expect(page).to have_table_row(count: 1)
      expect(page).to have_attribute_row('ID', exact_text: cdr.id)
      expect(page).to have_attribute_row('Routing Tags', exact_text: 'Empty')
      within_attribute_row('Routing Tags') do
        expect(page).to have_selector('.empty', exact_text: 'Empty')
      end
    end

    it 'shows attempts table' do
      subject
      expect(page).to have_table_row(count: 1)
      expect(page).to have_table_cell(column: 'Id', exact_text: cdr.id)
      expect(page).to have_table_cell(column: 'Routing Tags', exact_text: '')
    end
  end

  context 'when CDR has not recognized routing tag' do
    let(:cdr_attrs) do
      super().merge routing_tag_ids: [tag_ua.id, 9454, tag_us.id]
    end

    it 'shows CDR with correct attributes' do
      subject
      expect(page).to have_table_row(count: 1)
      expect(page).to have_attribute_row('ID', exact_text: cdr.id)
      expect(find(attributes_row_selector('Routing Tags')).text.split).to match_array([tag_ua.name, '9454', tag_us.name])
      within_attribute_row('Routing Tags') do
        expect(page).to have_selector('.status_tag.ok', exact_text: tag_ua.name)
        expect(page).to have_selector('.status_tag.no', exact_text: '9454')
        expect(page).to have_selector('.status_tag.ok', exact_text: tag_us.name)
      end
    end

    it 'shows attempts table' do
      subject
      expect(page).to have_table_row(count: 1)
      expect(page).to have_table_cell(column: 'Id', exact_text: cdr.id)
      expect(find(table_cell_selector('Routing Tags')).text.split).to match_array([tag_ua.name, '9454', tag_us.name])
      within_table_cell('Routing Tags') do
        expect(page).to have_selector('.status_tag.ok', exact_text: tag_ua.name)
        expect(page).to have_selector('.status_tag.no', exact_text: '9454')
        expect(page).to have_selector('.status_tag.ok', exact_text: tag_us.name)
      end
    end
  end

  context 'when CDR has attempts' do
    let(:cdr_attrs) do
      super().merge local_tag: 'some-local-tag', routing_attempt: 3, routing_tag_ids: [1234]
    end
    let!(:cdr_attempts) do
      [
        cdr,
        create(:cdr, :with_id, **cdr_attrs, routing_attempt: 2, routing_tag_ids: [tag_us.id]),
        create(:cdr, :with_id, **cdr_attrs, routing_attempt: 1, routing_tag_ids: [tag_ua.id])
      ]
    end

    it 'shows attempts table' do
      subject
      expect(page).to have_table_row(count: 3)
      within_table_row(index: 0) do
        expect(page).to have_table_cell(column: 'Id', exact_text: cdr_attempts.first.id)
        expect(page).to have_table_cell(column: 'Routing Tags', exact_text: '1234')
      end
      within_table_row(index: 1) do
        expect(page).to have_table_cell(column: 'Id', exact_text: cdr_attempts.second.id)
        expect(page).to have_table_cell(column: 'Routing Tags', exact_text: tag_us.name)
      end
      within_table_row(index: 2) do
        expect(page).to have_table_cell(column: 'Id', exact_text: cdr_attempts.third.id)
        expect(page).to have_table_cell(column: 'Routing Tags', exact_text: tag_ua.name)
      end
    end
  end

  context 'when CDR has dump file', js: true do
    let(:cdr_attrs) { super().merge(local_tag: 'some_local_tag', dump_level_id: 1, node_id: 25) }

    before do
      allow_any_instance_of(Cdr::CdrPolicy).to receive(:dump?).and_return(true)
    end

    it 'should setup X-Accel-Redirect header' do
      expect(Cdr::DownloadPcap).to receive(:call).with(cdr:, response_object: be_present).and_call_original

      subject

      click_on 'SIP trace'
      expect(response_headers['X-Accel-Redirect']).to eq('/dump/some_local_tag_25.pcap')
    end

    context 'when s3 storage is configured' do
      before do
        allow(YetiConfig).to receive(:s3_storage).and_return(
          OpenStruct.new(
            endpoint: 'http::some_example_s3_storage_url',
            pcap: OpenStruct.new(bucket: 'test-pcap-bucket'),
            call_record: OpenStruct.new(bucket: 'test-call-record-bucket')
          )
        )

        allow(S3AttachmentWrapper).to receive(:stream_to!).and_yield('dummy data')
      end

      it 'should download dump pcap file from S3' do
        expect(Cdr::DownloadPcap).to receive(:call).with(cdr:, response_object: be_present).and_call_original

        subject

        click_on 'SIP trace'
        expect(response_headers['Content-Disposition']).to eq('attachment; filename="some_local_tag_25.pcap"')
        expect(response_headers['Content-Type']).to eq('application/octet-stream')
        expect(page.current_path).to eq(cdr_path(id: cdr.id))
      end
    end

    context 'when Cdr::DownloadPcap::Error raised' do
      before do
        allow(Cdr::DownloadPcap).to receive(:call).and_raise(Cdr::DownloadPcap::Error, 'Some error occurred')
      end

      it 'shows an error message' do
        subject

        click_on 'SIP trace'
        expect(page).to have_flash_message('Some error occurred', type: :error)
      end
    end

    context 'when any other error raised' do
      before do
        allow(Cdr::DownloadPcap).to receive(:call).and_raise(StandardError, 'Some error occurred')
      end

      it 'shows an error message' do
        subject

        click_on 'SIP trace'
        expect(page).to have_flash_message('An unexpected error occurred: Some error occurred', type: :error)
      end
    end
  end

  context 'when CDR has record file file', js: true do
    let(:cdr_attrs) { super().merge(local_tag: 'some_local_tag', audio_recorded: true, duration: 3) }

    before do
      allow_any_instance_of(Cdr::CdrPolicy).to receive(:download_call_record?).and_return(true)
    end

    it 'should setup X-Accel-Redirect header' do
      subject

      click_on 'Call record'
      expect(response_headers['X-Accel-Redirect']).to eq('/record/some_local_tag.mp3')
      expect(response_headers['Content-Type']).to eq('audio/mpeg')
    end

    context 'when s3 storage is configured' do
      before do
        allow(YetiConfig).to receive(:s3_storage).and_return(
          OpenStruct.new(
            endpoint: 'http::some_example_s3_storage_url',
            pcap: OpenStruct.new(bucket: 'test-pcap-bucket'),
            call_record: OpenStruct.new(bucket: 'test-call-record-bucket')
          )
        )

        allow(S3AttachmentWrapper).to receive(:stream_to!).and_yield('dummy data')
      end

      it 'should download call record file from S3' do
        expect(Cdr::DownloadCallRecord).to receive(:call).with(cdr:, response_object: be_present).and_call_original

        subject

        click_on 'Call record'
        expect(response_headers['Content-Disposition']).to eq('attachment; filename="some_local_tag.mp3"')
        expect(response_headers['Content-Type']).to eq('application/octet-stream')
        expect(page.current_path).to eq(cdr_path(id: cdr.id))
      end
    end

    context 'when Cdr::DownloadCallRecord::Error raised' do
      before do
        allow(Cdr::DownloadCallRecord).to receive(:call).and_raise(Cdr::DownloadCallRecord::Error, 'Some error occurred')
      end

      it 'shows an error message' do
        subject

        click_on 'Call record'
        expect(page).to have_flash_message('Some error occurred', type: :error)
      end
    end

    context 'when any other error raised' do
      before do
        allow(Cdr::DownloadCallRecord).to receive(:call).and_raise(StandardError, 'Some error occurred')
      end

      it 'shows an error message' do
        subject

        click_on 'Call record'
        expect(page).to have_flash_message('An unexpected error occurred: Some error occurred', type: :error)
      end
    end
  end
end

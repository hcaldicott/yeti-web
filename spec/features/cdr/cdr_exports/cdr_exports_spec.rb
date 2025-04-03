# frozen_string_literal: true

RSpec.describe 'CDR exports', type: :feature do
  include_context :login_as_admin

  describe 'index' do
    subject do
      visit cdr_exports_path(q: { time_zone_name_eq: 'europe/kiev' })
    end

    let!(:account1) { create(:account, :with_customer) }
    let!(:account2) { create(:account, :with_customer) }
    let!(:cdr_exports) do
      [
        create(:cdr_export, time_zone_name: 'europe/kiev'),
        create(:cdr_export, :completed, time_zone_name: 'europe/kiev'),
        create(:cdr_export, :failed, time_zone_name: 'europe/kiev'),
        create(:cdr_export, :deleted, time_zone_name: 'europe/kiev'),
        create(:cdr_export, customer_account: account1, time_zone_name: 'europe/kiev'),
        create(:cdr_export, :completed, customer_account: account1, time_zone_name: 'europe/kiev'),
        create(:cdr_export, :deleted, customer_account: account2, time_zone_name: 'europe/kiev')
      ]
    end

    it 'cdr export should be displayed' do
      subject
      expect(page).to have_table_row count: cdr_exports.size
      expect(page).to have_select 'Time zone name', selected: 'europe/kiev', visible: false

      cdr_exports.each do |cdr_export|
        within_table_row(id: cdr_export.id) do
          expect(page).to have_table_cell column: 'ID', exact_text: cdr_export.id.to_s
          expect(page).to have_table_cell column: 'Download'
          expect(page).to have_table_cell column: 'Status', exact_text: cdr_export.status
          expect(page).to have_table_cell column: 'Fields', exact_text: cdr_export.fields.join(', ')
          expect(page).to have_table_cell column: 'Filters', exact_text: cdr_export.filters.as_json.to_s
          expect(page).to have_table_cell column: 'Callback Url', exact_text: cdr_export.callback_url.to_s
          expect(page).to have_table_cell column: 'Created At', exact_text: cdr_export.created_at.strftime('%F %T')
          expect(page).to have_table_cell column: 'Updated At', exact_text: cdr_export.updated_at.strftime('%F %T')
          expect(page).to have_table_cell column: 'UUID', exact_text: cdr_export.reload.uuid
        end
      end
    end
  end
end

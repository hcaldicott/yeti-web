# frozen_string_literal: true

class Api::Rest::Customer::V1::CdrsController < Api::Rest::Customer::V1::BaseController
  include TryCdrReplica

  around_action :try_cdr_replica
  before_action :find_cdr, only: :rec

  def rec
    if current_customer.allow_listen_recording && @cdr.has_recording?
      response.headers['X-Accel-Redirect'] = @cdr.call_record_filename
      response.headers['Content-Type'] = @cdr.call_record_ct
      render body: nil
    else
      head 404
    end
  rescue StandardError => e
    handle_exceptions(e)
  end

  private

  def find_cdr
    resource_klass = Api::Rest::Customer::V1::CdrResource
    key = resource_klass.verify_key(params[:id], context)
    @cdr = resource_klass.find_by_key(key, context: context)._model
  rescue StandardError => e
    handle_exceptions(e)
  end
end

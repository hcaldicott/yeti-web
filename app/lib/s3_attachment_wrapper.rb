# frozen_string_literal: true

class S3AttachmentWrapper
  def self.stream_to!(bucket_name, object_key, &)
    attachment = new(bucket_name, object_key)
    attachment.stream_to(&)
  end

  # Initialize with S3 bucket name and object key
  # @param bucket_name [String] the name of the S3 bucket
  # @param object_key [String] the key of the object in the S3 bucket
  def initialize(bucket_name, object_key)
    @bucket_name = bucket_name
    @object_key = object_key
  end

  def stream_to(&)
    return unless block_given?
    return if @bucket_name.blank? || @object_key.blank?

    object = ::Aws::S3::Object.new(bucket_name: @bucket_name, key: @object_key)
    object.get { |chunk, _| yield chunk }
  end
end

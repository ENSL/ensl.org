# frozen_string_literal: true

# Compatibility shim for dynamic_form 1.3.1 / ActiveModel::Errors.full_messages
compat = Module.new do
  def full_messages
    super
  rescue NameError
    msgs = []
    to_hash.each do |attribute, messages|
      Array(messages).each do |message|
        if attribute == :base || attribute.to_s == 'base'
          msgs << message
        else
          name = attribute.respond_to?(:attribute) ? attribute.attribute.to_s : attribute.to_s
          msgs << "#{name.humanize} #{message}"
        end
      end
    end
    msgs
  end
end

apply_patch = proc do
  if defined?(ActiveModel::Errors)
    begin
      ActiveModel::Errors.prepend(compat)
    rescue StandardError => _e
      # intentionally silent
    end
  end
end

# Apply now (covers cases where ActiveModel is already loaded)
apply_patch.call

# Also apply when ActiveModel loads later
ActiveSupport.on_load(:active_model) do
  apply_patch.call
end

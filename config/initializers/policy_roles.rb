# frozen_string_literal: true

policy_roles_path = Rails.root.join 'config/policy_roles.yml'
if File.file?(policy_roles_path)
  policy_roles = YAML.load_file(policy_roles_path, aliases: true).deep_symbolize_keys
  Rails.configuration.policy_roles = policy_roles
else
  Rails.configuration.policy_roles = nil
  rule = YetiConfig.role_policy.when_no_config
  case rule.to_sym
  when :allow, :disallow then
    Rails.logger.warn { "config/policy_roles.yml config is missing. Default rule is #{rule}." }
  when :raise then
    raise StandardError, 'config/policy_roles.yml config is missing.'
  end
end

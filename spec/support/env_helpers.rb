# frozen_string_literal: true

module EnvHelpers
  def apply_env_overrides(overrides)
    saved = overrides.keys.index_with { |k| ENV.fetch(k, nil) }
    begin
      overrides.each do |k, v|
        if v.nil?
          ENV.delete(k)
        else
          ENV[k] = v
        end
      end
      yield
    ensure
      saved.each do |k, v|
        if v.nil?
          ENV.delete(k)
        else
          ENV[k] = v
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end

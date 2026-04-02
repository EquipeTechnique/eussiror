# frozen_string_literal: true

module Eussiror
  # Normalizes heterogeneous Rails.error context payloads into a stable structure
  # consumed by issue formatting.
  module ContextExtractor
    class << self
      def normalize(context)
        ctx = context.is_a?(Hash) ? context : {}
        req = request_object(ctx)
        env = nested_hash(ctx, :env) || nested_hash(ctx, :rack)
        headers = nested_hash(ctx, :headers)

        {
          request_method: request_method(ctx, env, req),
          path: request_path(ctx, env, req),
          remote_ip: remote_ip(ctx, env, req),
          user_agent: user_agent(ctx, env, headers, req),
          user_id: user_id(ctx, env),
          user_label: user_label(ctx, env)
        }
      end

      private

      def request_method(ctx, env, req)
        resolve_field(
          [ctx, "REQUEST_METHOD"],
          [env, "REQUEST_METHOD"],
          [req, :request_method]
        )
      end

      def request_path(ctx, env, req)
        resolve_field(
          [ctx, "PATH_INFO"],
          [env, "PATH_INFO"],
          [ctx, "path"],
          [req, :fullpath],
          [req, :path]
        )
      end

      def remote_ip(ctx, env, req)
        resolve_field(
          [ctx, "REMOTE_ADDR"],
          [env, "REMOTE_ADDR"],
          [ctx, "remote_ip"],
          [req, :remote_ip],
          [ctx, "ip"],
          [req, :ip]
        )
      end

      def user_agent(ctx, env, headers, req)
        resolve_field(
          [ctx, "HTTP_USER_AGENT"],
          [env, "HTTP_USER_AGENT"],
          [headers, "User-Agent"],
          [headers, "HTTP_USER_AGENT"],
          [req, :user_agent]
        )
      end

      def user_id(ctx, env)
        resolve_field(
          [ctx, IssueFormatting::USER_ID_KEY],
          [env, IssueFormatting::USER_ID_KEY],
          [ctx, "user_id"]
        )
      end

      def user_label(ctx, env)
        resolve_field(
          [ctx, IssueFormatting::USER_LABEL_KEY],
          [env, IssueFormatting::USER_LABEL_KEY],
          [ctx, "user_label"]
        )
      end

      def request_object(context)
        fetch_key(context, "request") ||
          fetch_key(context, "request_object") ||
          fetch_key(context, "action_dispatch.request")
      end

      def nested_hash(context, key)
        val = fetch_key(context, key)
        val.is_a?(Hash) ? val : nil
      end

      def from_hash(container, key)
        return nil unless container

        if container.is_a?(Hash)
          fetch_key(container, key)
        elsif container.respond_to?(key)
          container.public_send(key)
        end
      rescue NoMethodError
        nil
      end

      def fetch_key(hash, key)
        return nil unless hash.is_a?(Hash)

        str_key = key.to_s
        hash[str_key] || hash[str_key.to_sym]
      end

      def resolve_field(*lookups)
        values = lookups.map { |(container, key)| from_hash(container, key) }
        first_present(*values)
      end

      def first_present(*values)
        values.find { |v| present_string?(v) }
      end

      def present_string?(value)
        !value.nil? && !value.to_s.strip.empty?
      end
    end
  end
end

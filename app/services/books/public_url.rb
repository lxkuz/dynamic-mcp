module Books
  module PublicUrl
    module_function

    def base
      explicit = ENV["PUBLIC_URL"].to_s.strip
      return explicit.delete_suffix("/") if explicit.present?

      host = ENV.fetch("PUBLIC_HOST", "localhost")
      scheme = ENV.fetch("PUBLIC_SCHEME", "http")
      port = public_port_for(host, scheme)
      return "#{scheme}://#{host}" if port.blank?

      "#{scheme}://#{host}:#{port}"
    end

    def path(path)
      "#{base}#{path}"
    end

    def public_port_for(host, scheme)
      return ENV["PUBLIC_PORT"].presence if ENV["PUBLIC_PORT"].present?

      local = host == "localhost" || host == "127.0.0.1"
      return ENV.fetch("WEB_PORT", "3020") if local

      nil
    end
  end
end

Rails.application.config.elasticsearch_url =
  ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200")

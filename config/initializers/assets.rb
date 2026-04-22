# Ensure the asset pipeline can find bundles emitted by jsbundling-rails.
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")

# Precompile the Rollup entrypoints and shared stylesheet.
Rails.application.config.assets.precompile += %w[
  application.js
  bjc.js
  schools.js
  application.css
]

# frozen_string_literal: true

# Keep legacy SCSS themes compiling with Dart Sass while migrating away from
# Bourbon/Neat over time.
Rails.application.config.dartsass.builds = {
  'themes/default/theme.css.scss' => 'themes/default/theme.css',
  'themes/default/errors.css.scss' => 'themes/default/errors.css',
  'themes/flat/theme.css.scss' => 'themes/flat/theme.css',
  'themes/flat/errors.css.scss' => 'themes/flat/errors.css'
}

Rails.application.config.dartsass.build_options << '--quiet-deps'
